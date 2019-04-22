RSpec.describe Recache do

  before :all do
    @recache = Recache.new(
      redis:  { host: '127.0.0.1' },
      pool:   { size: 2, timeout: 5 },
      namespace: 'test'
    )
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

end
