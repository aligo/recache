require 'recache/version'

require 'redis'
require 'connection_pool'
require 'oj'

class Recache
  attr_reader :pool

  def initialize(config)
    @config = config
    @pool = ConnectionPool.new(@config[:pool]) do
      Redis.new(@config[:redis])
    end
  end

  def get(key)
    @pool.with do |redis|
      if cached_data = redis.get(key_with_namespace(key))
        Oj.load(cached_data, mode: :object)
      end
    end
  end

  def set(key, data, options = {})
    options[:expire] ||= 1800

    _key = key_with_namespace(key)
    @pool.with do |redis|
      redis.pipelined do
        redis.set(_key, Oj.dump(data, mode: :object))
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

  def cached_for(key, options = {}, &block)
    options[:lifetime]  ||= 1800
    options[:expire]    ||= 0
    options[:wait_time] ||= 0.2
    options[:max_wait_time] ||= 0.8

    need_update = true
    if cache_data = self.get(key)
      old_data = cache_data[:d]
      need_update = cache_data[:t].to_i < (Time.now - options[:lifetime]).to_i
    end
    if need_update
      _key = key_with_namespace(key)
      @pool.with do |redis|
        if redis.get(_key + '@r')
          sleep(options[:wait_time])
          options[:wait_time] += options[:wait_time] if options[:wait_time] < options[:max_wait_time]
          return self.cached_for(key, options, &block)
        else
          redis.set(_key + '@r', '1')
        end
      end
      if new_data = yield
        cache_data = {d: new_data, t: Time.now.to_i}
        self.set(key, cache_data, expire: options[:expire])
      end
      @pool.with do |redis|
        redis.del(_key + '@r')
      end
    end
    new_data || old_data || options[:default]
  end

  def key_with_namespace(key)
    "#{@config[:namespace]}:#{key}"
  end


end
