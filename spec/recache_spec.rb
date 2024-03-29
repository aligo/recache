RSpec.describe Recache do

  before :all do
    @recache = Recache.new(
      redis:  { host: '127.0.0.1' },
      pool:   { size: 2, timeout: 5 },
      namespace: 'test'
    )
    @recache.touch_wildcard 'test'
  end

  it "has a version number" do
    expect(Recache::VERSION).not_to be nil
  end

  it "can set and get" do
    @recache.set('test', 'hello world')

    expect(@recache.get('test')).to eq('hello world')
  end

  it "can touch" do
    @recache.set('test1', 'hello world')
    expect(@recache.get('test1')).to eq('hello world')
    @recache.touch('test1')
    expect(@recache.get('test1')).to eq(nil)
  end

  it "can touch wildcard" do
    @recache.set('test2', 'hello world')
    @recache.set('test3', 'hello world')
    expect(@recache.get('test2')).to eq('hello world')
    expect(@recache.get('test3')).to eq('hello world')
    @recache.touch_wildcard('test')
    expect(@recache.get('test2')).to eq(nil)
    expect(@recache.get('test3')).to eq(nil)
  end

  it "can cached_for block" do
    expect(
      @recache.cached_for('test4') do
        'hello'
      end
    ).to eq('hello')
    expect(
      @recache.cached_for('test4') do
        'world'
      end
    ).to eq('hello')
    expect(
      @recache.cached_for('test4', lifetime: -1) do
        'world'
      end
    ).to eq('world')
  end

  it "can cached_for with pubsub" do
    Thread.new do
      expect(
        @recache.cached_for('test5') do
          sleep 0.5
          'hello'
        end
      ).to eq('hello')
    end

    sleep 0.1
    expect(
      @recache.cached_for('test5') do
        'world'
      end
    ).to eq('hello')
  end

  it "can get and set sub hash" do
    @recache.set('test6', 'hello world', sub: 'key')
    expect(@recache.get('test6', sub: 'key')).to eq('hello world')
    @recache.touch('test6')
    expect(@recache.get('test6', sub: 'key')).to eq(nil)
  end

  it "can cached_for with sub hash" do
    expect(
      @recache.cached_for('test7', sub: 'key') do
        'hello'
      end
    ).to eq('hello')
    expect(
      @recache.cached_for('test7', sub: 'key') do
        'world'
      end
    ).to eq('hello')
  end

  it "can cached_for with no_mutex_lock" do
    2.times.map do |i|
      sleep 0.1
      Thread.new do
        @recache.cached_for('lock', lifetime: 0) do
          sleep 0.5
          i
        end
      end
    end.each(&:join)
    expect(@recache.get('lock')[:d]).to eq(0)

    2.times.map do |i|
      sleep 0.1
      Thread.new do
        @recache.cached_for('no_lock', no_mutex_lock: true, lifetime: 0) do
          sleep 0.5
          i
        end
      end
    end.each(&:join)
    expect(@recache.get('no_lock')[:d]).to eq(1)
  end

end
