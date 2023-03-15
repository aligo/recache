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

  def get(key, options = {})
    _key = key_with_namespace(key)
    if cached_data = (@pool.with {|r| options[:sub] ? r.hget(_key, options[:sub]) : r.get(_key) })
      Oj.load(cached_data, mode: :object)
    end
  end

  def set(key, data, options = {})
    options[:expire] ||= 1800

    _key = key_with_namespace(key)
    _value = Oj.dump(data, mode: :object)
    @pool.with do |redis|
      redis.pipelined do
        if options[:sub]
          redis.hset(_key, options[:sub], _value)
        else
          redis.set(_key, _value)
        end
        redis.expire(_key, options[:expire].to_i) if options[:expire].to_i > 0
      end
    end
  end

  def touch(*keys)
    @pool.with do |redis|
      redis.pipelined do
        keys.each do |key|
          redis.del(key_with_namespace(key))
        end
      end
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
    options[:lock_expire] ||= 3
    options[:no_mutex_lock] ||= false

    need_update = true
    if cache_data = self.get(key, sub: options[:sub])
      old_data = cache_data[:d]
      need_update = cache_data[:t].to_i < (Time.now - options[:lifetime]).to_i
    end
    if need_update
      _key = key_with_namespace(key)
      lock_key = _key + '@r'
      unless options[:no_mutex_lock]
        if @pool.with{|r| r.get(lock_key)}
          sleep(options[:wait_time])
          if options[:wait_time] < options[:max_wait_time]
            options[:wait_time] += options[:wait_time]
            return self.cached_for(key, options, &block)
          elsif old_data
            return old_data
          end
        else
          @pool.with do |r|
            r.set(lock_key, '1')
            r.expire(lock_key, options[:lock_expire].to_i)
          end
        end
      end
      if new_data = yield
        cache_data = {d: new_data, t: Time.now.to_i}
        self.set(key, cache_data, expire: options[:expire], sub: options[:sub])
      end
      unless options[:no_mutex_lock]
        @pool.with{|r| r.del(lock_key)}
      end
    end
    new_data || old_data || options[:default]
  end

  def key_with_namespace(key)
    "#{@config[:namespace]}:#{key}"
  end


end
