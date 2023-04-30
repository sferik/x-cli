# encoding: utf-8

require 'helper'

describe T::List do
  before :all do
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0))
    T.utc_offset = 'PST'
  end

  before do
    T::RCFile.instance.path = "#{fixture_path}/.trc"
    @list = T::List.new
    @old_stderr = $stderr
    $stderr = StringIO.new
    @old_stdout = $stdout
    $stdout = StringIO.new
  end

  after do
    T::RCFile.instance.reset
    $stderr = @old_stderr
    $stdout = @old_stdout
  end

  after :all do
    T.utc_offset = nil
    Timecop.return
  end

  describe '#add' do
    before do
      @list.options = @list.options.merge('profile' => "#{fixture_path}/.trc")
      stub_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_post('/1.1/lists/members/create_all.json').with(body: {screen_name: 'BarackObama', slug: 'presidents', owner_id: '7505382'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @list.add('presidents', 'BarackObama')
      expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
      expect(a_post('/1.1/lists/members/create_all.json').with(body: {screen_name: 'BarackObama', slug: 'presidents', owner_id: '7505382'})).to have_been_made
    end
    it 'has the correct output' do
      @list.add('presidents', 'BarackObama')
      expect($stdout.string.split("\n").first).to eq '@testcli added 1 member to the list "presidents".'
    end
    context '--id' do
      before do
        @list.options = @list.options.merge('id' => true)
        stub_post('/1.1/lists/members/create_all.json').with(body: {user_id: '7505382', slug: 'presidents', owner_id: '7505382'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @list.add('presidents', '7505382')
        expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
        expect(a_post('/1.1/lists/members/create_all.json').with(body: {user_id: '7505382', slug: 'presidents', owner_id: '7505382'})).to have_been_made
      end
    end
    context 'Twitter is down' do
      it 'retries 3 times and then raise an error' do
        stub_post('/1.1/lists/members/create_all.json').with(body: {screen_name: 'BarackObama', slug: 'presidents', owner_id: '7505382'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
        expect do
          @list.add('presidents', 'BarackObama')
        end.to raise_error(Twitter::Error::BadGateway)
        expect(a_post('/1.1/lists/members/create_all.json').with(body: {screen_name: 'BarackObama', slug: 'presidents', owner_id: '7505382'})).to have_been_made.times(3)
      end
    end
  end

  describe '#create' do
    before do
      @list.options = @list.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/lists/create.json').with(body: {name: 'presidents'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @list.create('presidents')
      expect(a_post('/1.1/lists/create.json').with(body: {name: 'presidents'})).to have_been_made
    end
    it 'has the correct output' do
      @list.create('presidents')
      expect($stdout.string.chomp).to eq '@testcli created the list "presidents".'
    end
  end

  describe '#information' do
    before do
      @list.options = @list.options.merge('profile' => "#{fixture_path}/.trc")
      stub_get('/1.1/lists/show.json').with(query: {owner_screen_name: 'testcli', slug: 'presidents'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @list.information('presidents')
      expect(a_get('/1.1/lists/show.json').with(query: {owner_screen_name: 'testcli', slug: 'presidents'})).to have_been_made
    end
    it 'has the correct output' do
      @list.information('presidents')
      expect($stdout.string).to eq <<~EOS
        ID           8863586
        Description  Presidents of the United States of America
        Slug         presidents
        Screen name  @sferik
        Created at   Mar 15  2010 (a year ago)
        Members      2
        Subscribers  1
        Status       Not following
        Mode         public
        URL          https://twitter.com/sferik/presidents
      EOS
    end
    it 'has the correct output with --relative-dates turned on' do
      @list.options = @list.options.merge('relative_dates' => true)
      @list.information('presidents')
      expect($stdout.string).to eq <<~EOS
        ID           8863586
        Description  Presidents of the United States of America
        Slug         presidents
        Screen name  @sferik
        Created at   Mar 15  2010 (a year ago)
        Members      2
        Subscribers  1
        Status       Not following
        Mode         public
        URL          https://twitter.com/sferik/presidents
      EOS
    end
    context 'with a user passed' do
      it 'requests the correct resource' do
        @list.information('testcli/presidents')
        expect(a_get('/1.1/lists/show.json').with(query: {owner_screen_name: 'testcli', slug: 'presidents'})).to have_been_made
      end
      context '--id' do
        before do
          @list.options = @list.options.merge('id' => true)
          stub_get('/1.1/lists/show.json').with(query: {owner_id: '7505382', slug: 'presidents'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @list.information('7505382/presidents')
          expect(a_get('/1.1/lists/show.json').with(query: {owner_id: '7505382', slug: 'presidents'})).to have_been_made
        end
      end
    end
    context '--csv' do
      before do
        @list.options = @list.options.merge('csv' => true)
      end
      it 'has the correct output' do
        @list.information('presidents')
        expect($stdout.string).to eq <<~EOS
          ID,Description,Slug,Screen name,Created at,Members,Subscribers,Following,Mode,URL
          8863586,Presidents of the United States of America,presidents,sferik,2010-03-15 12:10:13 +0000,2,1,false,public,https://twitter.com/sferik/presidents
        EOS
      end
    end
  end

  describe '#members' do
    before do
      stub_get('/1.1/lists/members.json').with(query: {cursor: '-1', owner_screen_name: 'testcli', slug: 'presidents'}).to_return(body: fixture('users_list.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @list.members('presidents')
      expect(a_get('/1.1/lists/members.json').with(query: {cursor: '-1', owner_screen_name: 'testcli', slug: 'presidents'})).to have_been_made
    end
    it 'has the correct output' do
      @list.members('presidents')
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @list.options = @list.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @list.members('presidents')
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @list.options = @list.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @list.members('presidents')
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @list.options = @list.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @list.members('presidents')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @list.options = @list.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @list.members('presidents')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @list.options = @list.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @list.members('presidents')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @list.options = @list.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @list.members('presidents')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=listed' do
      before do
        @list.options = @list.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @list.members('presidents')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @list.options = @list.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter account was created' do
        @list.members('presidents')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @list.options = @list.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @list.members('presidents')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @list.options = @list.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @list.members('presidents')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @list.options = @list.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @list.members('presidents')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context 'with a user passed' do
      it 'requests the correct resource' do
        @list.members('testcli/presidents')
        expect(a_get('/1.1/lists/members.json').with(query: {cursor: '-1', owner_screen_name: 'testcli', slug: 'presidents'})).to have_been_made
      end
      context '--id' do
        before do
          @list.options = @list.options.merge('id' => true)
          stub_get('/1.1/lists/members.json').with(query: {cursor: '-1', owner_id: '7505382', slug: 'presidents'}).to_return(body: fixture('users_list.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @list.members('7505382/presidents')
          expect(a_get('/1.1/lists/members.json').with(query: {cursor: '-1', owner_id: '7505382', slug: 'presidents'})).to have_been_made
        end
      end
    end
  end

  describe '#remove' do
    before do
      @list.options = @list.options.merge('profile' => "#{fixture_path}/.trc")
      stub_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      stub_post('/1.1/lists/members/destroy_all.json').with(body: {screen_name: 'BarackObama', slug: 'presidents', owner_id: '7505382'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
      @list.remove('presidents', 'BarackObama')
      expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
      expect(a_post('/1.1/lists/members/destroy_all.json').with(body: {screen_name: 'BarackObama', slug: 'presidents', owner_id: '7505382'})).to have_been_made
    end
    it 'has the correct output' do
      stub_post('/1.1/lists/members/destroy_all.json').with(body: {screen_name: 'BarackObama', slug: 'presidents', owner_id: '7505382'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
      @list.remove('presidents', 'BarackObama')
      expect($stdout.string.split("\n").first).to eq '@testcli removed 1 member from the list "presidents".'
    end
    context '--id' do
      before do
        @list.options = @list.options.merge('id' => true)
        stub_post('/1.1/lists/members/destroy_all.json').with(body: {user_id: '7505382', slug: 'presidents', owner_id: '7505382'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @list.remove('presidents', '7505382')
        expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
        expect(a_post('/1.1/lists/members/destroy_all.json').with(body: {user_id: '7505382', slug: 'presidents', owner_id: '7505382'})).to have_been_made
      end
    end
    context 'Twitter is down' do
      it 'retries 3 times and then raise an error' do
        stub_post('/1.1/lists/members/destroy_all.json').with(body: {screen_name: 'BarackObama', slug: 'presidents', owner_id: '7505382'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
        expect do
          @list.remove('presidents', 'BarackObama')
        end.to raise_error(Twitter::Error::BadGateway)
        expect(a_post('/1.1/lists/members/destroy_all.json').with(body: {screen_name: 'BarackObama', slug: 'presidents', owner_id: '7505382'})).to have_been_made.times(3)
      end
    end
  end

  describe '#timeline' do
    before do
      @list.options = @list.options.merge('color' => 'always')
      stub_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '20', slug: 'presidents', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @list.timeline('presidents')
      expect(a_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '20', slug: 'presidents', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @list.timeline('presidents')
      expect($stdout.string).to eq <<-EOS
   @mutgoff
   Happy Birthday @imdane. Watch out for those @rally pranksters!

   @ironicsans
   If you like good real-life stories, check out @NarrativelyNY's just-launched
   site http://t.co/wiUL07jE (and also visit http://t.co/ZoyQxqWA)

   @pat_shaughnessy
   Something else to vote for: "New Rails workshops to bring more women into
   the Boston software scene" http://t.co/eNBuckHc /cc @bostonrb

   @calebelston
   Pushing the button to launch the site. http://t.co/qLoEn5jG

   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

   @fivethirtyeight
   The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from my
   book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)

   @codeforamerica
   RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
   Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
   @TheaClay

   @fbjork
   RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
   http://t.co/kGEykswZ /cc @JRuby @headius

   @mbostock
   If you are wondering how we computed the split bubbles: http://t.co/BcaqSs5u

   @FakeDorsey
   "Write drunk. Edit sober."—Ernest Hemingway

   @al3x
   RT @wcmaier: Better banking through better ops: build something new with us
   @Simplify (remote, PDX) http://t.co/8WgzKZH3

   @calebelston
   We just announced Mosaic, what we've been working on since the Yobongo
   acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic

   @BarackObama
   Donate $10 or more --> get your favorite car magnet: http://t.co/NfRhl2s2
   #Obama2012

   @JEG2
   RT @tenderlove: If corporations are people, can we use them to drive in the
   carpool lane?

   @eveningedition
   LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes shake
   China; Canada cuts Iran ties; weekend read: http://t.co/OFs6dVW4

   @dhh
   RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest
   achievement: why this goulish jingoism is so warped http://t.co/kood278s

   @jasonfried
   The story of Mars Curiosity's gears, made by a factory in Rockford, IL:
   http://t.co/MwCRsHQg

   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
   to be missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

   @dwiskus
   Gentlemen, you can't fight in here! This is the war room!
   http://t.co/kMxMYyqF

      EOS
    end
    context '--color=never' do
      before do
        @list.options = @list.options.merge('color' => 'never')
      end
      it 'outputs without color' do
        @list.timeline('presidents')
        expect($stdout.string).to eq <<-EOS
   @mutgoff
   Happy Birthday @imdane. Watch out for those @rally pranksters!

   @ironicsans
   If you like good real-life stories, check out @NarrativelyNY's just-launched
   site http://t.co/wiUL07jE (and also visit http://t.co/ZoyQxqWA)

   @pat_shaughnessy
   Something else to vote for: "New Rails workshops to bring more women into
   the Boston software scene" http://t.co/eNBuckHc /cc @bostonrb

   @calebelston
   Pushing the button to launch the site. http://t.co/qLoEn5jG

   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

   @fivethirtyeight
   The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from my
   book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)

   @codeforamerica
   RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
   Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
   @TheaClay

   @fbjork
   RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
   http://t.co/kGEykswZ /cc @JRuby @headius

   @mbostock
   If you are wondering how we computed the split bubbles: http://t.co/BcaqSs5u

   @FakeDorsey
   "Write drunk. Edit sober."—Ernest Hemingway

   @al3x
   RT @wcmaier: Better banking through better ops: build something new with us
   @Simplify (remote, PDX) http://t.co/8WgzKZH3

   @calebelston
   We just announced Mosaic, what we've been working on since the Yobongo
   acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic

   @BarackObama
   Donate $10 or more --> get your favorite car magnet: http://t.co/NfRhl2s2
   #Obama2012

   @JEG2
   RT @tenderlove: If corporations are people, can we use them to drive in the
   carpool lane?

   @eveningedition
   LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes shake
   China; Canada cuts Iran ties; weekend read: http://t.co/OFs6dVW4

   @dhh
   RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest
   achievement: why this goulish jingoism is so warped http://t.co/kood278s

   @jasonfried
   The story of Mars Curiosity's gears, made by a factory in Rockford, IL:
   http://t.co/MwCRsHQg

   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
   to be missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

   @dwiskus
   Gentlemen, you can't fight in here! This is the war room!
   http://t.co/kMxMYyqF

        EOS
      end
    end
    context '--color=auto' do
      before do
        @list.options = @list.options.merge('color' => 'auto')
      end
      it 'outputs without color when stdout is not a tty' do
        @list.timeline('presidents')
        expect($stdout.string).to eq <<-EOS
   @mutgoff
   Happy Birthday @imdane. Watch out for those @rally pranksters!

   @ironicsans
   If you like good real-life stories, check out @NarrativelyNY's just-launched
   site http://t.co/wiUL07jE (and also visit http://t.co/ZoyQxqWA)

   @pat_shaughnessy
   Something else to vote for: "New Rails workshops to bring more women into
   the Boston software scene" http://t.co/eNBuckHc /cc @bostonrb

   @calebelston
   Pushing the button to launch the site. http://t.co/qLoEn5jG

   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

   @fivethirtyeight
   The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from my
   book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)

   @codeforamerica
   RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
   Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
   @TheaClay

   @fbjork
   RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
   http://t.co/kGEykswZ /cc @JRuby @headius

   @mbostock
   If you are wondering how we computed the split bubbles: http://t.co/BcaqSs5u

   @FakeDorsey
   "Write drunk. Edit sober."—Ernest Hemingway

   @al3x
   RT @wcmaier: Better banking through better ops: build something new with us
   @Simplify (remote, PDX) http://t.co/8WgzKZH3

   @calebelston
   We just announced Mosaic, what we've been working on since the Yobongo
   acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic

   @BarackObama
   Donate $10 or more --> get your favorite car magnet: http://t.co/NfRhl2s2
   #Obama2012

   @JEG2
   RT @tenderlove: If corporations are people, can we use them to drive in the
   carpool lane?

   @eveningedition
   LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes shake
   China; Canada cuts Iran ties; weekend read: http://t.co/OFs6dVW4

   @dhh
   RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest
   achievement: why this goulish jingoism is so warped http://t.co/kood278s

   @jasonfried
   The story of Mars Curiosity's gears, made by a factory in Rockford, IL:
   http://t.co/MwCRsHQg

   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
   to be missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

   @dwiskus
   Gentlemen, you can't fight in here! This is the war room!
   http://t.co/kMxMYyqF

        EOS
      end
      it 'outputs with color when stdout is a tty' do
        allow($stdout).to receive(:tty?).and_return(true)
        @list.timeline('presidents')
        expect($stdout.string).to eq <<~EOS
          \e[1m\e[33m   @mutgoff\e[0m
             Happy Birthday @imdane. Watch out for those @rally pranksters!
          
          \e[1m\e[33m   @ironicsans\e[0m
             If you like good real-life stories, check out @NarrativelyNY's just-launched
             site http://t.co/wiUL07jE (and also visit http://t.co/ZoyQxqWA)
          
          \e[1m\e[33m   @pat_shaughnessy\e[0m
             Something else to vote for: "New Rails workshops to bring more women into
             the Boston software scene" http://t.co/eNBuckHc /cc @bostonrb
          
          \e[1m\e[33m   @calebelston\e[0m
             Pushing the button to launch the site. http://t.co/qLoEn5jG
          
          \e[1m\e[33m   @calebelston\e[0m
             RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
          
          \e[1m\e[33m   @fivethirtyeight\e[0m
             The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from my
             book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)
          
          \e[1m\e[33m   @codeforamerica\e[0m
             RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
             Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
             @TheaClay
          
          \e[1m\e[33m   @fbjork\e[0m
             RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
             http://t.co/kGEykswZ /cc @JRuby @headius
          
          \e[1m\e[33m   @mbostock\e[0m
             If you are wondering how we computed the split bubbles: http://t.co/BcaqSs5u
          
          \e[1m\e[33m   @FakeDorsey\e[0m
             "Write drunk. Edit sober."—Ernest Hemingway
          
          \e[1m\e[33m   @al3x\e[0m
             RT @wcmaier: Better banking through better ops: build something new with us
             @Simplify (remote, PDX) http://t.co/8WgzKZH3
          
          \e[1m\e[33m   @calebelston\e[0m
             We just announced Mosaic, what we've been working on since the Yobongo
             acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic
          
          \e[1m\e[33m   @BarackObama\e[0m
             Donate $10 or more --> get your favorite car magnet: http://t.co/NfRhl2s2
             #Obama2012
          
          \e[1m\e[33m   @JEG2\e[0m
             RT @tenderlove: If corporations are people, can we use them to drive in the
             carpool lane?
          
          \e[1m\e[33m   @eveningedition\e[0m
             LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes shake
             China; Canada cuts Iran ties; weekend read: http://t.co/OFs6dVW4
          
          \e[1m\e[33m   @dhh\e[0m
             RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest
             achievement: why this goulish jingoism is so warped http://t.co/kood278s
          
          \e[1m\e[33m   @jasonfried\e[0m
             The story of Mars Curiosity's gears, made by a factory in Rockford, IL:
             http://t.co/MwCRsHQg
          
          \e[1m\e[33m   @sferik\e[0m
             @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem
             to be missing "1.1" from the URL.
          
          \e[1m\e[33m   @sferik\e[0m
             @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
          
          \e[1m\e[33m   @dwiskus\e[0m
             Gentlemen, you can't fight in here! This is the war room!
             http://t.co/kMxMYyqF
          
        EOS
      end
    end
    context '--color=icon' do
      before do
        @list.options = @list.options.merge('color' => 'icon')
      end
      it 'outputs with color when stdout is a tty' do
        allow($stdout).to receive(:tty?).and_return(true)
        @list.timeline('presidents')

        names = %w[mutgoff ironicsans pat_shaughnessy calebelston fivethirtyeight
                   codeforamerica fbjork mbostock FakeDorsey al3x BarackObama
                   JEG2 eveningedition dhh jasonfried sferik dwiskus]

        icons = names.inject({}) { |acc, elem| acc.update(elem.to_sym => T::Identicon.for_user_name(elem)) }

        expect($stdout.string).to eq <<-EOS
  #{icons[:mutgoff].lines[0]}\e[1m\e[33m  @mutgoff\e[0m
  #{icons[:mutgoff].lines[1]}  Happy Birthday @imdane. Watch out for those @rally pranksters!
  #{icons[:mutgoff].lines[2]}


  #{icons[:ironicsans].lines[0]}\e[1m\e[33m  @ironicsans\e[0m
  #{icons[:ironicsans].lines[1]}  If you like good real-life stories, check out @NarrativelyNY's 
  #{icons[:ironicsans].lines[2]}  just-launched site http://t.co/wiUL07jE (and also visit 
          http://t.co/ZoyQxqWA)


  #{icons[:pat_shaughnessy].lines[0]}\e[1m\e[33m  @pat_shaughnessy\e[0m
  #{icons[:pat_shaughnessy].lines[1]}  Something else to vote for: "New Rails workshops to bring more women 
  #{icons[:pat_shaughnessy].lines[2]}  into the Boston software scene" http://t.co/eNBuckHc /cc @bostonrb


  #{icons[:calebelston].lines[0]}\e[1m\e[33m  @calebelston\e[0m
  #{icons[:calebelston].lines[1]}  Pushing the button to launch the site. http://t.co/qLoEn5jG
  #{icons[:calebelston].lines[2]}


  #{icons[:calebelston].lines[0]}\e[1m\e[33m  @calebelston\e[0m
  #{icons[:calebelston].lines[1]}  RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
  #{icons[:calebelston].lines[2]}


  #{icons[:fivethirtyeight].lines[0]}\e[1m\e[33m  @fivethirtyeight\e[0m
  #{icons[:fivethirtyeight].lines[1]}  The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from 
  #{icons[:fivethirtyeight].lines[2]}  my book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)


  #{icons[:codeforamerica].lines[0]}\e[1m\e[33m  @codeforamerica\e[0m
  #{icons[:codeforamerica].lines[1]}  RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, 
  #{icons[:codeforamerica].lines[2]}  Sat, Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok 
          @codeforamerica @TheaClay


  #{icons[:fbjork].lines[0]}\e[1m\e[33m  @fbjork\e[0m
  #{icons[:fbjork].lines[1]}  RT @jondot: Just published: "Pragmatic Concurrency With #Ruby" 
  #{icons[:fbjork].lines[2]}  http://t.co/kGEykswZ /cc @JRuby @headius


  #{icons[:mbostock].lines[0]}\e[1m\e[33m  @mbostock\e[0m
  #{icons[:mbostock].lines[1]}  If you are wondering how we computed the split bubbles: 
  #{icons[:mbostock].lines[2]}  http://t.co/BcaqSs5u


  #{icons[:FakeDorsey].lines[0]}\e[1m\e[33m  @FakeDorsey\e[0m
  #{icons[:FakeDorsey].lines[1]}  "Write drunk. Edit sober."—Ernest Hemingway
  #{icons[:FakeDorsey].lines[2]}


  #{icons[:al3x].lines[0]}\e[1m\e[33m  @al3x\e[0m
  #{icons[:al3x].lines[1]}  RT @wcmaier: Better banking through better ops: build something new 
  #{icons[:al3x].lines[2]}  with us @Simplify (remote, PDX) http://t.co/8WgzKZH3


  #{icons[:calebelston].lines[0]}\e[1m\e[33m  @calebelston\e[0m
  #{icons[:calebelston].lines[1]}  We just announced Mosaic, what we've been working on since the 
  #{icons[:calebelston].lines[2]}  Yobongo acquisition. My personal post, http://t.co/ELOyIRZU 
          @heymosaic


  #{icons[:BarackObama].lines[0]}\e[1m\e[33m  @BarackObama\e[0m
  #{icons[:BarackObama].lines[1]}  Donate $10 or more --> get your favorite car magnet: 
  #{icons[:BarackObama].lines[2]}  http://t.co/NfRhl2s2 #Obama2012


  #{icons[:JEG2].lines[0]}\e[1m\e[33m  @JEG2\e[0m
  #{icons[:JEG2].lines[1]}  RT @tenderlove: If corporations are people, can we use them to drive 
  #{icons[:JEG2].lines[2]}  in the carpool lane?


  #{icons[:eveningedition].lines[0]}\e[1m\e[33m  @eveningedition\e[0m
  #{icons[:eveningedition].lines[1]}  LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes 
  #{icons[:eveningedition].lines[2]}  shake China; Canada cuts Iran ties; weekend read: 
          http://t.co/OFs6dVW4


  #{icons[:dhh].lines[0]}\e[1m\e[33m  @dhh\e[0m
  #{icons[:dhh].lines[1]}  RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their 
  #{icons[:dhh].lines[2]}  proudest achievement: why this goulish jingoism is so warped 
          http://t.co/kood278s


  #{icons[:jasonfried].lines[0]}\e[1m\e[33m  @jasonfried\e[0m
  #{icons[:jasonfried].lines[1]}  The story of Mars Curiosity's gears, made by a factory in Rockford, 
  #{icons[:jasonfried].lines[2]}  IL: http://t.co/MwCRsHQg


  #{icons[:sferik].lines[0]}\e[1m\e[33m  @sferik\e[0m
  #{icons[:sferik].lines[1]}  @episod @twitterapi now https://t.co/I17jUTu2 and 
  #{icons[:sferik].lines[2]}  https://t.co/deDu4Hgw seem to be missing "1.1" from the URL.


  #{icons[:sferik].lines[0]}\e[1m\e[33m  @sferik\e[0m
  #{icons[:sferik].lines[1]}  @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
  #{icons[:sferik].lines[2]}


  #{icons[:dwiskus].lines[0]}\e[1m\e[33m  @dwiskus\e[0m
  #{icons[:dwiskus].lines[1]}  Gentlemen, you can't fight in here! This is the war room! 
  #{icons[:dwiskus].lines[2]}  http://t.co/kMxMYyqF


        EOS
      end
    end

    context '--csv' do
      before do
        @list.options = @list.options.merge('csv' => true)
      end
      it 'outputs in long format' do
        @list.timeline('presidents')
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          4611686018427387904,2012-09-07 16:35:24 +0000,mutgoff,Happy Birthday @imdane. Watch out for those @rally pranksters!
          244111183165157376,2012-09-07 16:33:36 +0000,ironicsans,"If you like good real-life stories, check out @NarrativelyNY's just-launched site http://t.co/wiUL07jE (and also visit http://t.co/ZoyQxqWA)"
          244110336414859264,2012-09-07 16:30:14 +0000,pat_shaughnessy,"Something else to vote for: ""New Rails workshops to bring more women into the Boston software scene"" http://t.co/eNBuckHc /cc @bostonrb"
          244109797308379136,2012-09-07 16:28:05 +0000,calebelston,Pushing the button to launch the site. http://t.co/qLoEn5jG
          244108728834592770,2012-09-07 16:23:50 +0000,calebelston,RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
          244107890632294400,2012-09-07 16:20:31 +0000,fivethirtyeight,"The Weatherman is Not a Moron: http://t.co/ZwL5Gnq5. An excerpt from my book, THE SIGNAL AND THE NOISE (http://t.co/fNXj8vCE)"
          244107823733174272,2012-09-07 16:20:15 +0000,codeforamerica,"RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat, Sep 8 http://t.co/Sk5BM7U3  We'll see y'all there! #rhok @codeforamerica @TheaClay"
          244107236262170624,2012-09-07 16:17:55 +0000,fbjork,"RT @jondot: Just published: ""Pragmatic Concurrency With #Ruby"" http://t.co/kGEykswZ   /cc @JRuby @headius"
          244106476048764928,2012-09-07 16:14:53 +0000,mbostock,If you are wondering how we computed the split bubbles: http://t.co/BcaqSs5u
          244105599351148544,2012-09-07 16:11:24 +0000,FakeDorsey,"""Write drunk. Edit sober.""—Ernest Hemingway"
          244104558433951744,2012-09-07 16:07:16 +0000,al3x,"RT @wcmaier: Better banking through better ops: build something new with us @Simplify (remote, PDX) http://t.co/8WgzKZH3"
          244104146997870594,2012-09-07 16:05:38 +0000,calebelston,"We just announced Mosaic, what we've been working on since the Yobongo acquisition. My personal post, http://t.co/ELOyIRZU @heymosaic"
          244103057175113729,2012-09-07 16:01:18 +0000,BarackObama,Donate $10 or more --> get your favorite car magnet: http://t.co/NfRhl2s2 #Obama2012
          244102834398851073,2012-09-07 16:00:25 +0000,JEG2,"RT @tenderlove: If corporations are people, can we use them to drive in the carpool lane?"
          244102741125890048,2012-09-07 16:00:03 +0000,eveningedition,LDN—Obama's nomination; Putin woos APEC; Bombs hit Damascus; Quakes shake China; Canada cuts Iran ties; weekend read: http://t.co/OFs6dVW4
          244102729860009984,2012-09-07 16:00:00 +0000,dhh,RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest achievement: why this goulish jingoism is so warped http://t.co/kood278s
          244102490646278146,2012-09-07 15:59:03 +0000,jasonfried,"The story of Mars Curiosity's gears, made by a factory in Rockford, IL: http://t.co/MwCRsHQg"
          244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
          244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
          244099460672679938,2012-09-07 15:47:01 +0000,dwiskus,"Gentlemen, you can't fight in here! This is the war room! http://t.co/kMxMYyqF"
        EOS
      end
    end
    context '--decode-uris' do
      before do
        @list.options = @list.options.merge('decode_uris' => true)
        stub_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '20', slug: 'presidents', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @list.timeline('presidents')
        expect(a_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '20', slug: 'presidents', include_entities: 'true'})).to have_been_made
      end
      it 'decodes URLs' do
        @list.timeline('presidents')
        expect($stdout.string).to include 'https://twitter.com/sferik/status/243988000076337152'
      end
    end
    context '--long' do
      before do
        @list.options = @list.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @list.timeline('presidents')
        expect($stdout.string).to eq <<~EOS
          ID                   Posted at     Screen name       Text
          4611686018427387904  Sep  7 08:35  @mutgoff          Happy Birthday @imdane. ...
           244111183165157376  Sep  7 08:33  @ironicsans       If you like good real-li...
           244110336414859264  Sep  7 08:30  @pat_shaughnessy  Something else to vote f...
           244109797308379136  Sep  7 08:28  @calebelston      Pushing the button to la...
           244108728834592770  Sep  7 08:23  @calebelston      RT @olivercameron: Mosai...
           244107890632294400  Sep  7 08:20  @fivethirtyeight  The Weatherman is Not a ...
           244107823733174272  Sep  7 08:20  @codeforamerica   RT @randomhacks: Going t...
           244107236262170624  Sep  7 08:17  @fbjork           RT @jondot: Just publish...
           244106476048764928  Sep  7 08:14  @mbostock         If you are wondering how...
           244105599351148544  Sep  7 08:11  @FakeDorsey       "Write drunk. Edit sober...
           244104558433951744  Sep  7 08:07  @al3x             RT @wcmaier: Better bank...
           244104146997870594  Sep  7 08:05  @calebelston      We just announced Mosaic...
           244103057175113729  Sep  7 08:01  @BarackObama      Donate $10 or more --> g...
           244102834398851073  Sep  7 08:00  @JEG2             RT @tenderlove: If corpo...
           244102741125890048  Sep  7 08:00  @eveningedition   LDN—Obama's nomination; ...
           244102729860009984  Sep  7 08:00  @dhh              RT @ggreenwald: Democrat...
           244102490646278146  Sep  7 07:59  @jasonfried       The story of Mars Curios...
           244102209942458368  Sep  7 07:57  @sferik           @episod @twitterapi now ...
           244100411563339777  Sep  7 07:50  @sferik           @episod @twitterapi Did ...
           244099460672679938  Sep  7 07:47  @dwiskus          Gentlemen, you can't fig...
        EOS
      end
      context '--reverse' do
        before do
          @list.options = @list.options.merge('reverse' => true)
        end
        it 'reverses the order of the sort' do
          @list.timeline('presidents')
          expect($stdout.string).to eq <<~EOS
            ID                   Posted at     Screen name       Text
             244099460672679938  Sep  7 07:47  @dwiskus          Gentlemen, you can't fig...
             244100411563339777  Sep  7 07:50  @sferik           @episod @twitterapi Did ...
             244102209942458368  Sep  7 07:57  @sferik           @episod @twitterapi now ...
             244102490646278146  Sep  7 07:59  @jasonfried       The story of Mars Curios...
             244102729860009984  Sep  7 08:00  @dhh              RT @ggreenwald: Democrat...
             244102741125890048  Sep  7 08:00  @eveningedition   LDN—Obama's nomination; ...
             244102834398851073  Sep  7 08:00  @JEG2             RT @tenderlove: If corpo...
             244103057175113729  Sep  7 08:01  @BarackObama      Donate $10 or more --> g...
             244104146997870594  Sep  7 08:05  @calebelston      We just announced Mosaic...
             244104558433951744  Sep  7 08:07  @al3x             RT @wcmaier: Better bank...
             244105599351148544  Sep  7 08:11  @FakeDorsey       "Write drunk. Edit sober...
             244106476048764928  Sep  7 08:14  @mbostock         If you are wondering how...
             244107236262170624  Sep  7 08:17  @fbjork           RT @jondot: Just publish...
             244107823733174272  Sep  7 08:20  @codeforamerica   RT @randomhacks: Going t...
             244107890632294400  Sep  7 08:20  @fivethirtyeight  The Weatherman is Not a ...
             244108728834592770  Sep  7 08:23  @calebelston      RT @olivercameron: Mosai...
             244109797308379136  Sep  7 08:28  @calebelston      Pushing the button to la...
             244110336414859264  Sep  7 08:30  @pat_shaughnessy  Something else to vote f...
             244111183165157376  Sep  7 08:33  @ironicsans       If you like good real-li...
            4611686018427387904  Sep  7 08:35  @mutgoff          Happy Birthday @imdane. ...
          EOS
        end
      end
    end
    context '--number' do
      before do
        stub_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '1', slug: 'presidents', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '200', slug: 'presidents', include_entities: 'false'}).to_return(body: fixture('200_statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '1', max_id: '265500541700956160', slug: 'presidents', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'limits the number of results to 1' do
        @list.options = @list.options.merge('number' => 1)
        @list.timeline('presidents')
        expect(a_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '1', slug: 'presidents', include_entities: 'false'})).to have_been_made
      end
      it 'limits the number of results to 201' do
        @list.options = @list.options.merge('number' => 201)
        @list.timeline('presidents')
        expect(a_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '200', slug: 'presidents', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '1', max_id: '265500541700956160', slug: 'presidents', include_entities: 'false'})).to have_been_made
      end
    end
    context 'with a user passed' do
      it 'requests the correct resource' do
        @list.timeline('testcli/presidents')
        expect(a_get('/1.1/lists/statuses.json').with(query: {owner_screen_name: 'testcli', count: '20', slug: 'presidents', include_entities: 'false'})).to have_been_made
      end
      context '--id' do
        before do
          @list.options = @list.options.merge('id' => true)
          stub_get('/1.1/lists/statuses.json').with(query: {owner_id: '7505382', count: '20', slug: 'presidents', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @list.timeline('7505382/presidents')
          expect(a_get('/1.1/lists/statuses.json').with(query: {owner_id: '7505382', count: '20', slug: 'presidents', include_entities: 'false'})).to have_been_made
        end
      end
    end
  end
end
