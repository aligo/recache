require 'recache/version'

require 'redis'
require 'connection_pool'
require 'oj'

class Recache

  def initialize(config)
    @config = config
    @pool = ConnectionPool.new(@config[:pool]) do
      Redis.new(@config[:redis])
    end
  end

  def get(key)
    @pool.with do |redis|
      if cached_data = redis.get(key_with_namespace(key))
        Oj.load(cached_data)
      end
    end
  end

  def set(key, data, options = {})
    options[:expire] ||= 1800

    _key = key_with_namespace(key)
    @pool.with do |redis|
      redis.pipelined do
        redis.set(_key, Oj.dump(data))
        redis.expire(_key, options[:expire]) if options[:expire].to_i > 0
      end
    end
  end

  def touch(key)
    @pool.with do |redis|
      redis.del(key_with_namespace(key))
    end
  end

  def touch_wildcard(key)
    @pool.with do |redis|
      keys = redis.keys "#{key_with_namespace(key)}*"
      redis.del(*keys) if keys && ( keys.length > 0 )
    end
  end

  def cached_for(key, options = {})
    options[:lifetime] ||= 1800
    options[:expire] ||= 0

    _key = key_with_namespace(key)
    need_update = true
    if cache_data = self.get(_key)
      old_data = cache_data[:d]
      need_update = cache_data[:t].to_i < (Time.now - options[:lifetime]).to_i
    end
    if need_update
      if new_data = yield
        cache_data = {d: new_data, t: Time.now.to_i}
        self.set(_key, cache_data, expire: options[:expire])
      end
    end
    new_data || old_data || options[:default]
  end

  private

  def key_with_namespace(key)
    "#{@config[:namespace]}:#{key}"
  end


end
