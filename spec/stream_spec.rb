require 'helper'

describe T::Stream do
  let(:t_class) do
    klass = Class.new
    allow(klass).to receive(:options=)
    allow(klass).to receive(:options).and_return({})
    klass
  end

  before :all do
    @tweet = tweet_from_fixture('status.json')
  end

  before do
    T::RCFile.instance.path = fixture_path + '/.trc'
    @streaming_client = double('Twitter::Streaming::Client').as_null_object
    @stream = T::Stream.new
    allow(@stream).to receive(:streaming_client) { @streaming_client }
    allow(@stream).to receive(:say)
    allow(STDOUT).to receive(:tty?).and_return(true)
  end

  describe '#all' do
    before do
      allow(@streaming_client).to receive(:sample).and_yield(@tweet)
    end
    it 'prints the tweet' do
      expect(@stream).to receive(:print_message)
      @stream.all
    end
    context '--csv' do
      before do
        @stream.options = @stream.options.merge('csv' => true)
      end
      it 'outputs headings when the stream initializes' do
        allow(@streaming_client).to receive(:before_request).and_yield
        allow(@streaming_client).to receive(:sample)
        expect(@stream).to receive(:say).with("ID,Posted at,Screen name,Text\n")
        @stream.all
      end
      it 'outputs in CSV format' do
        allow(@streaming_client).to receive(:before_request)
        allow(@streaming_client).to receive(:sample).and_yield(@tweet)
        expect(@stream).to receive(:print_csv_tweet).with(any_args)
        @stream.all
      end
    end
    context '--long' do
      before do
        @stream.options = @stream.options.merge('long' => true)
      end
      it 'outputs headings when the stream initializes' do
        allow(@streaming_client).to receive(:before_request).and_yield
        allow(@streaming_client).to receive(:sample)
        expect(@stream).to receive(:print_table).with(any_args)
        @stream.all
      end
      it 'outputs in long text format' do
        allow(@streaming_client).to receive(:before_request)
        allow(@streaming_client).to receive(:sample).and_yield(@tweet)
        expect(@stream).to receive(:print_table).with(any_args)
        @stream.all
      end
    end
    it 'invokes Twitter::Streaming::Client#sample' do
      allow(@streaming_client).to receive(:before_request)
      allow(@streaming_client).to receive(:sample)
      expect(@streaming_client).to receive(:sample)
      @stream.all
    end
  end

  describe '#list' do
    before do
      stub_get('/1.1/lists/members.json').with(query: {cursor: '-1', owner_screen_name: 'testcli', slug: 'presidents'}).to_return(body: fixture('users_list.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'prints the tweet' do
      expect(@stream).to receive(:print_message)
      allow(@streaming_client).to receive(:filter).and_yield(@tweet)
      @stream.list('presidents')
    end
    it 'requests the correct resource' do
      @stream.list('presidents')
      expect(a_get('/1.1/lists/members.json').with(query: {cursor: '-1', owner_screen_name: 'testcli', slug: 'presidents'})).to have_been_made
    end
    context '--csv' do
      before do
        @stream.options = @stream.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        allow(@streaming_client).to receive(:before_request)
        allow(@streaming_client).to receive(:filter).and_yield(@tweet)
        expect(@stream).to receive(:print_csv_tweet).with(any_args)
        @stream.list('presidents')
      end
      it 'requests the correct resource' do
        @stream.list('presidents')
        expect(a_get('/1.1/lists/members.json').with(query: {cursor: '-1', owner_screen_name: 'testcli', slug: 'presidents'})).to have_been_made
      end
    end
    context '--long' do
      before do
        @stream.options = @stream.options.merge('long' => true)
      end
      it 'outputs in long text format' do
        allow(@streaming_client).to receive(:before_request)
        allow(@streaming_client).to receive(:filter).and_yield(@tweet)
        expect(@stream).to receive(:print_table).with(any_args)
        @stream.list('presidents')
      end
      it 'requests the correct resource' do
        @stream.list('presidents')
        expect(a_get('/1.1/lists/members.json').with(query: {cursor: '-1', owner_screen_name: 'testcli', slug: 'presidents'})).to have_been_made
      end
    end
    it 'performs a REST search when the stream initializes' do
      allow(@streaming_client).to receive(:before_request).and_yield
      allow(@streaming_client).to receive(:filter)
      allow(T::List).to receive(:new).and_return(t_class)
      expect(t_class).to receive(:timeline)
      @stream.list('presidents')
    end
    it 'invokes Twitter::Streaming::Client#userstream' do
      allow(@streaming_client).to receive(:filter)
      expect(@streaming_client).to receive(:filter)
      @stream.list('presidents')
    end
  end

  describe '#matrix' do
    before do
      stub_get('/1.1/search/tweets.json').with(query: {q: 'lang:ja', count: 100, include_entities: 'false'}).to_return(body: fixture('empty_cursor.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'outputs the tweet' do
      allow(@streaming_client).to receive(:before_request)
      allow(@streaming_client).to receive(:sample).and_yield(@tweet)
      expect(@stream).to receive(:say).with(any_args)
      @stream.matrix
    end
    it 'invokes Twitter::Streaming::Client#sample' do
      allow(@streaming_client).to receive(:before_request)
      allow(@streaming_client).to receive(:sample).and_yield(@tweet)
      expect(@streaming_client).to receive(:sample)
      @stream.matrix
    end
    it 'requests the correct resource' do
      allow(@streaming_client).to receive(:before_request).and_yield
      @stream.matrix
      expect(a_get('/1.1/search/tweets.json').with(query: {q: 'lang:ja', count: 100, include_entities: 'false'})).to have_been_made
    end
  end

  describe '#search' do
    before do
      allow(@streaming_client).to receive(:filter).with(track: 'twitter,gem').and_yield(@tweet)
    end
    it 'prints the tweet' do
      expect(@stream).to receive(:print_message)
      @stream.search(%w[twitter gem])
    end
    context '--csv' do
      before do
        @stream.options = @stream.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        allow(@streaming_client).to receive(:before_request)
        expect(@stream).to receive(:print_csv_tweet).with(any_args)
        @stream.search(%w[twitter gem])
      end
    end
    context '--long' do
      before do
        @stream.options = @stream.options.merge('long' => true)
      end
      it 'outputs in long text format' do
        allow(@streaming_client).to receive(:before_request)
        allow(@streaming_client).to receive(:filter).with(track: 'twitter,gem').and_yield(@tweet)
        expect(@stream).to receive(:print_table).with(any_args)
        @stream.search(%w[twitter gem])
      end
    end
    it 'performs a REST search when the stream initializes' do
      allow(@streaming_client).to receive(:before_request).and_yield
      allow(@streaming_client).to receive(:filter)
      allow(T::Search).to receive(:new).and_return(t_class)
      expect(t_class).to receive(:all).with('t OR gem')
      @stream.search('t', 'gem')
    end
    it 'invokes Twitter::Streaming::Client#filter' do
      allow(@streaming_client).to receive(:filter)
      expect(@streaming_client).to receive(:filter).with(track: 'twitter,gem')
      @stream.search(%w[twitter gem])
    end
  end

  describe '#timeline' do
    before do
      allow(@streaming_client).to receive(:user).and_yield(@tweet)
    end
    it 'prints the tweet' do
      expect(@stream).to receive(:print_message)
      @stream.timeline
    end
    context '--csv' do
      before do
        @stream.options = @stream.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        allow(@streaming_client).to receive(:before_request)
        expect(@stream).to receive(:print_csv_tweet).with(any_args)
        @stream.timeline
      end
    end
    context '--long' do
      before do
        @stream.options = @stream.options.merge('long' => true)
      end
      it 'outputs in long text format' do
        allow(@streaming_client).to receive(:before_request)
        expect(@stream).to receive(:print_table).with(any_args)
        @stream.timeline
      end
    end
    it 'performs a REST search when the stream initializes' do
      allow(@streaming_client).to receive(:before_request).and_yield
      allow(@streaming_client).to receive(:user)
      allow(T::CLI).to receive(:new).and_return(t_class)
      expect(t_class).to receive(:timeline)
      @stream.timeline
    end
    it 'invokes Twitter::Streaming::Client#userstream' do
      allow(@streaming_client).to receive(:user)
      expect(@streaming_client).to receive(:user)
      @stream.timeline
    end
  end

  describe '#users' do
    before do
      allow(@streaming_client).to receive(:filter).and_yield(@tweet)
    end
    it 'prints the tweet' do
      expect(@stream).to receive(:print_message)
      @stream.users('123')
    end
    context '--csv' do
      before do
        @stream.options = @stream.options.merge('csv' => true)
      end
      it 'outputs headings when the stream initializes' do
        allow(@streaming_client).to receive(:before_request).and_yield
        allow(@streaming_client).to receive(:filter)
        expect(@stream).to receive(:say).with("ID,Posted at,Screen name,Text\n")
        @stream.users('123')
      end
      it 'outputs in CSV format' do
        allow(@streaming_client).to receive(:before_request)
        expect(@stream).to receive(:print_csv_tweet).with(any_args)
        @stream.users('123')
      end
    end
    context '--long' do
      before do
        @stream.options = @stream.options.merge('long' => true)
      end
      it 'outputs headings when the stream initializes' do
        allow(@streaming_client).to receive(:before_request).and_yield
        allow(@streaming_client).to receive(:filter)
        expect(@stream).to receive(:print_table).with(any_args)
        @stream.users('123')
      end
      it 'outputs in long text format' do
        allow(@streaming_client).to receive(:before_request)
        allow(@streaming_client).to receive(:filter).and_yield(@tweet)
        expect(@stream).to receive(:print_table).with(any_args)
        @stream.users('123')
      end
    end
    it 'invokes Twitter::Streaming::Client#follow' do
      allow(@streaming_client).to receive(:filter)
      expect(@streaming_client).to receive(:filter).with(follow: '123,456,789')
      @stream.users('123', '456', '789')
    end
  end
end
