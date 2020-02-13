# encoding: utf-8

require 'helper'

describe T::Search do
  before :all do
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0))
    T.utc_offset = 'PST'
  end

  before do
    T::RCFile.instance.path = fixture_path + '/.trc'
    @search = T::Search.new
    @search.options = @search.options.merge('color' => 'always')
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

  describe '#all' do
    before do
      stub_get('/1.1/search/tweets.json').with(query: {q: 'twitter', count: '100', include_entities: 'false'}).to_return(body: fixture('search.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @search.all('twitter')
      expect(a_get('/1.1/search/tweets.json').with(query: {q: 'twitter', count: '100', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @search.all('twitter')
      expect($stdout.string).to eq <<-EOS

   @amaliasafitri2
   RT @heartCOBOYJR: @AlvaroMaldini1 :-) http://t.co/Oxce0Tob3n

   @BPDPipesDrums
   Here is a picture of us getting ready to Santa into @CITCBoston! #Boston
   http://t.co/INACljvLLC

   @yunistosun6034
   RT @sevilayyaziyor: gerçekten @ademyavuza ?Nasıl elin vardı böyle bi twit
   atmaya?Yolsuzlukla olmadı terörle mi şantaj yaparız diyosunuz?
   http://t.co/YPtNVYhLxl

   @_KAIRYALS
   My birthday cake was bomb http://t.co/LquXc7JXj4

   @frozenharryx
   RT @LouisTexts: whos tessa? http://t.co/7DJQlmCfuu

   @MIKEFANTASMA
   Pues nada, aquí armando mi regalo de navidad solo me falta la cara y ya hago mi
   pedido con santa!.. http://t.co/iDC7bE9o4M

   @EleManera
   RT @xmyband: La gente che si arrabbia perché Harry non ha fatto gli auguri a
   Lou su Twitter. Non vorrei smontarvi, ma esistono i cellulari e i messaggi.

   @BigAlFerguson
   “@IrishRace; Merry Christmas to all our friends and followers from all @IrishRaceRally
   have a good one! http://t.co/rXFsC2ncFo” @Danloi1

   @goksantezgel
   RT @nederlandline: Tayyip bey evladımızı severiz Biz ona dua
   ediyoruz.Fitnelere SAKIN HA! Mahmud Efndi (ks) #BedduayaLanetDuayaDavet
   http://t.co/h6MUyHxr9x"

   @MaimounaLvb
   RT @sissokodiaro: Miss mali pa pour les moche mon ga http://t.co/4WnwzoLgAD

   @MrSilpy
   @MrKATANI http://t.co/psk7K8rcND

   @hunterdl19
   RT @MadisonBertini: Jakes turnt http://t.co/P60gYZNL8z

   @jayjay42__
   RT @SteveStfler: Megan Fox Naked >> http://t.co/hMKlUMydFp

   @Bs1972Bill
   RT @erorin691: おはよう♪ http://t.co/v5YIFriCW3

   @naked_gypsy
   All my friends are here 😂 http://t.co/w66iG4XXpL

   @whoa_lashton
   @Ashton5SOS http://t.co/uhYwoRY0Iz

   @seyfullaharpaci
   RT @Dedekorkut11: Utanmadıktan sonra... #CamiayaİftiraYolsuzluğuÖrtmez
   http://t.co/sXPn17D2md

   @NNGrilli
   esperando la Navidad :D http://t.co/iwBL2Xj3g7

   @omersafak74
   RT @1903Rc: Ben Beşiktaşlıyım.. http://t.co/qnEpDJwI3b

   @bryony_thfc
   merry christmas you arse X http://t.co/yRiWFgqr7p

      EOS
    end
    context '--csv' do
      before do
        @search.options = @search.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @search.all('twitter')
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          415600159511158784,2013-12-24 21:49:34 +0000,amaliasafitri2,RT @heartCOBOYJR: @AlvaroMaldini1 :-) http://t.co/Oxce0Tob3n
          415600159490580480,2013-12-24 21:49:34 +0000,BPDPipesDrums,Here is a picture of us getting ready to Santa into @CITCBoston! #Boston http://t.co/INACljvLLC
          415600159486406656,2013-12-24 21:49:34 +0000,yunistosun6034,RT @sevilayyaziyor: gerçekten @ademyavuza ?Nasıl elin vardı böyle bi twit atmaya?Yolsuzlukla olmadı terörle mi şantaj yaparız diyosunuz? http://t.co/YPtNVYhLxl
          415600159486005248,2013-12-24 21:49:34 +0000,_KAIRYALS,My birthday cake was bomb http://t.co/LquXc7JXj4
          415600159456632832,2013-12-24 21:49:34 +0000,frozenharryx,RT @LouisTexts: whos tessa? http://t.co/7DJQlmCfuu
          415600159452438528,2013-12-24 21:49:34 +0000,MIKEFANTASMA,"Pues nada, aquí armando mi regalo de navidad solo me falta la cara y ya hago mi pedido con santa!.. http://t.co/iDC7bE9o4M"
          415600159444439040,2013-12-24 21:49:34 +0000,EleManera,"RT @xmyband: La gente che si arrabbia perché Harry non ha fatto gli auguri a Lou su Twitter.
          Non vorrei smontarvi, ma esistono i cellulari e i messaggi."
          415600159444434944,2013-12-24 21:49:34 +0000,BigAlFerguson,“@IrishRace; Merry Christmas to all our friends and followers from all @IrishRaceRally have a good one! http://t.co/rXFsC2ncFo” @Danloi1
          415600159436066816,2013-12-24 21:49:34 +0000,goksantezgel,"RT @nederlandline: Tayyip bey evladımızı severiz Biz ona dua ediyoruz.Fitnelere SAKIN HA!
          Mahmud Efndi (ks)
          #BedduayaLanetDuayaDavet 
          http://t.co/h6MUyHxr9x"""
          415600159427670016,2013-12-24 21:49:34 +0000,MaimounaLvb,RT @sissokodiaro: Miss mali pa pour les moche mon ga http://t.co/4WnwzoLgAD
          415600159423483904,2013-12-24 21:49:34 +0000,MrSilpy,@MrKATANI http://t.co/psk7K8rcND
          415600159423094784,2013-12-24 21:49:34 +0000,hunterdl19,RT @MadisonBertini: Jakes turnt http://t.co/P60gYZNL8z
          415600159419277312,2013-12-24 21:49:34 +0000,jayjay42__,RT @SteveStfler: Megan Fox Naked >> http://t.co/hMKlUMydFp
          415600159415103488,2013-12-24 21:49:34 +0000,Bs1972Bill,RT @erorin691: おはよう♪ http://t.co/v5YIFriCW3
          415600159415091200,2013-12-24 21:49:34 +0000,naked_gypsy,All my friends are here 😂 http://t.co/w66iG4XXpL
          415600159398313984,2013-12-24 21:49:34 +0000,whoa_lashton,@Ashton5SOS http://t.co/uhYwoRY0Iz
          415600159389937664,2013-12-24 21:49:34 +0000,seyfullaharpaci,RT @Dedekorkut11: Utanmadıktan sonra... #CamiayaİftiraYolsuzluğuÖrtmez http://t.co/sXPn17D2md
          415600159389519872,2013-12-24 21:49:34 +0000,NNGrilli,esperando la Navidad :D http://t.co/iwBL2Xj3g7
          415600159373144064,2013-12-24 21:49:34 +0000,omersafak74,RT @1903Rc: Ben Beşiktaşlıyım.. http://t.co/qnEpDJwI3b
          415600159372767232,2013-12-24 21:49:34 +0000,bryony_thfc,merry christmas you arse X http://t.co/yRiWFgqr7p
        EOS
      end
    end
    context '--long' do
      before do
        @search.options = @search.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @search.all('twitter')
        expect($stdout.string).to eq <<~EOS
          ID                  Posted at     Screen name       Text
          415600159511158784  Dec 24 13:49  @amaliasafitri2   RT @heartCOBOYJR: @Alvaro...
          415600159490580480  Dec 24 13:49  @BPDPipesDrums    Here is a picture of us g...
          415600159486406656  Dec 24 13:49  @yunistosun6034   RT @sevilayyaziyor: gerçe...
          415600159486005248  Dec 24 13:49  @_KAIRYALS        My birthday cake was bomb...
          415600159456632832  Dec 24 13:49  @frozenharryx     RT @LouisTexts: whos tess...
          415600159452438528  Dec 24 13:49  @MIKEFANTASMA     Pues nada, aquí armando m...
          415600159444439040  Dec 24 13:49  @EleManera        RT @xmyband: La gente che...
          415600159444434944  Dec 24 13:49  @BigAlFerguson    “@IrishRace; Merry Christ...
          415600159436066816  Dec 24 13:49  @goksantezgel     RT @nederlandline: Tayyip...
          415600159427670016  Dec 24 13:49  @MaimounaLvb      RT @sissokodiaro: Miss ma...
          415600159423483904  Dec 24 13:49  @MrSilpy          @MrKATANI http://t.co/psk...
          415600159423094784  Dec 24 13:49  @hunterdl19       RT @MadisonBertini: Jakes...
          415600159419277312  Dec 24 13:49  @jayjay42__       RT @SteveStfler: Megan Fo...
          415600159415103488  Dec 24 13:49  @Bs1972Bill       RT @erorin691: おはよう♪ http...
          415600159415091200  Dec 24 13:49  @naked_gypsy      All my friends are here 😂...
          415600159398313984  Dec 24 13:49  @whoa_lashton     @Ashton5SOS http://t.co/u...
          415600159389937664  Dec 24 13:49  @seyfullaharpaci  RT @Dedekorkut11: Utanmad...
          415600159389519872  Dec 24 13:49  @NNGrilli         esperando la Navidad :D h...
          415600159373144064  Dec 24 13:49  @omersafak74      RT @1903Rc: Ben Beşiktaşl...
          415600159372767232  Dec 24 13:49  @bryony_thfc      merry christmas you arse ...
        EOS
      end
    end
    context '--number' do
      before do
        stub_get('/1.1/search/tweets.json').with(query: {q: 'twitter', count: '1', include_entities: 'false'}).to_return(body: fixture('search2.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/search/tweets.json').with(query: {q: 'twitter', count: '100', include_entities: 'false'}).to_return(body: fixture('search.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/search/tweets.json').with(query: {q: 'twitter', count: '100', include_entities: '1', max_id: '415600158693675007'}).to_return(body: fixture('search2.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'limits the number of results to 1' do
        @search.options = @search.options.merge('number' => 1)
        @search.all('twitter')
        expect(a_get('/1.1/search/tweets.json').with(query: {q: 'twitter', count: '100', include_entities: 'false'})).to have_been_made
      end
      it 'limits the number of results to 201' do
        @search.options = @search.options.merge('number' => 201)
        @search.all('twitter')
        expect(a_get('/1.1/search/tweets.json').with(query: {q: 'twitter', count: '100', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/search/tweets.json').with(query: {q: 'twitter', count: '100', include_entities: '1', max_id: '415600158693675007'})).to have_been_made
      end
    end
  end

  describe '#favorites' do
    before do
      stub_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/favorites/list.json').with(query: {count: '200', max_id: '244099460672679937', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @search.favorites('twitter')
      expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made
      expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', max_id: '244099460672679937', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @search.favorites('twitter')
      expect($stdout.string).to eq <<-EOS
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be
   missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

      EOS
    end
    context '--csv' do
      before do
        @search.options = @search.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @search.favorites('twitter')
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
          244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
        EOS
      end
    end
    context '--decode-uris' do
      before(:each) do
        @search.options = @search.options.merge('decode_uris' => true)
        stub_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'true', max_id: '244099460672679937'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.favorites('twitter')
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'true'})).to have_been_made
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'true', max_id: '244099460672679937'})).to have_been_made
      end
      it 'decodes URLs' do
        @search.favorites('twitter')
        expect($stdout.string).to include 'https://twitter.com/sferik/status/243988000076337152'
      end
    end
    context '--long' do
      before do
        @search.options = @search.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @search.favorites('twitter')
        expect($stdout.string).to eq <<~EOS
          ID                  Posted at     Screen name  Text
          244102209942458368  Sep  7 07:57  @sferik      @episod @twitterapi now https:...
          244100411563339777  Sep  7 07:50  @sferik      @episod @twitterapi Did you ca...
        EOS
      end
    end
    context 'Twitter is down' do
      it 'retries 3 times and then raise an error' do
        stub_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'false'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
        expect do
          @search.favorites('twitter')
        end.to raise_error(Twitter::Error::BadGateway)
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made.times(3)
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/favorites/list.json').with(query: {count: '200', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/favorites/list.json').with(query: {count: '200', max_id: '244099460672679937', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.favorites('sferik', 'twitter')
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', max_id: '244099460672679937', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
      end
      it 'has the correct output' do
        @search.favorites('sferik', 'twitter')
        expect($stdout.string).to eq <<-EOS
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be
   missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

        EOS
      end
      context '--id' do
        before do
          @search.options = @search.options.merge('id' => true)
          stub_get('/1.1/favorites/list.json').with(query: {count: '200', user_id: '7505382', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/favorites/list.json').with(query: {count: '200', max_id: '244099460672679937', user_id: '7505382', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @search.favorites('7505382', 'twitter')
          expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', user_id: '7505382', include_entities: 'false'})).to have_been_made
          expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', max_id: '244099460672679937', user_id: '7505382', include_entities: 'false'})).to have_been_made
        end
        it 'has the correct output' do
          @search.favorites('7505382', 'twitter')
          expect($stdout.string).to eq <<-EOS
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be
   missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

          EOS
        end
      end
    end
  end

  describe '#mentions' do
    before do
      stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', max_id: '244099460672679937', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @search.mentions('twitter')
      expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made
      expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', max_id: '244099460672679937', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @search.mentions('twitter')
      expect($stdout.string).to eq <<-EOS
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be
   missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

      EOS
    end
    context '--csv' do
      before do
        @search.options = @search.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @search.mentions('twitter')
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
          244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
        EOS
      end
    end
    context '--decode-uris' do
      before(:each) do
        @search.options = @search.options.merge('decode_uris' => true)
        stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'true', max_id: '244099460672679937'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.mentions('twitter')
        expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'true'})).to have_been_made
        expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'true', max_id: '244099460672679937'})).to have_been_made
      end
      it 'decodes URLs' do
        @search.mentions('twitter')
        expect($stdout.string).to include 'https://twitter.com/sferik/status/243988000076337152'
      end
    end
    context '--long' do
      before do
        @search.options = @search.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @search.mentions('twitter')
        expect($stdout.string).to eq <<~EOS
          ID                  Posted at     Screen name  Text
          244102209942458368  Sep  7 07:57  @sferik      @episod @twitterapi now https:...
          244100411563339777  Sep  7 07:50  @sferik      @episod @twitterapi Did you ca...
        EOS
      end
    end
    context 'Twitter is down' do
      it 'retries 3 times and then raise an error' do
        stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'false'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
        expect do
          @search.mentions('twitter')
        end.to raise_error(Twitter::Error::BadGateway)
        expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made.times(3)
      end
    end
  end

  describe '#list' do
    before do
      stub_get('/1.1/lists/statuses.json').with(query: {count: '200', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/lists/statuses.json').with(query: {count: '200', max_id: '244099460672679937', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @search.list('presidents', 'twitter')
      expect(a_get('/1.1/lists/statuses.json').with(query: {count: '200', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'false'})).to have_been_made
      expect(a_get('/1.1/lists/statuses.json').with(query: {count: '200', max_id: '244099460672679937', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @search.list('presidents', 'twitter')
      expect($stdout.string).to eq <<-EOS
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be
   missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

      EOS
    end
    context '--csv' do
      before do
        @search.options = @search.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @search.list('presidents', 'twitter')
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
          244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
        EOS
      end
    end
    context '--decode-uris' do
      before(:each) do
        @search.options = @search.options.merge('decode_uris' => true)
        stub_get('/1.1/lists/statuses.json').with(query: {count: '200', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/lists/statuses.json').with(query: {count: '200', max_id: '244099460672679937', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'true'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.list('presidents', 'twitter')
        expect(a_get('/1.1/lists/statuses.json').with(query: {count: '200', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'true'})).to have_been_made
        expect(a_get('/1.1/lists/statuses.json').with(query: {count: '200', max_id: '244099460672679937', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'true'})).to have_been_made
      end
      it 'decodes URLs' do
        @search.list('presidents', 'twitter')
        expect($stdout.string).to include 'https://dev.twitter.com/docs/api/post/direct_messages/destroy'
      end
    end
    context '--long' do
      before do
        @search.options = @search.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @search.list('presidents', 'twitter')
        expect($stdout.string).to eq <<~EOS
          ID                  Posted at     Screen name  Text
          244102209942458368  Sep  7 07:57  @sferik      @episod @twitterapi now https:...
          244100411563339777  Sep  7 07:50  @sferik      @episod @twitterapi Did you ca...
        EOS
      end
    end
    context 'with a user passed' do
      it 'requests the correct resource' do
        @search.list('testcli/presidents', 'twitter')
        expect(a_get('/1.1/lists/statuses.json').with(query: {count: '200', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'false'})).to have_been_made
      end
      context '--id' do
        before do
          @search.options = @search.options.merge('id' => true)
          stub_get('/1.1/lists/statuses.json').with(query: {count: '200', owner_id: '7505382', slug: 'presidents', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/lists/statuses.json').with(query: {count: '200', max_id: '244099460672679937', owner_id: '7505382', slug: 'presidents', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @search.list('7505382/presidents', 'twitter')
          expect(a_get('/1.1/lists/statuses.json').with(query: {count: '200', owner_id: '7505382', slug: 'presidents', include_entities: 'false'})).to have_been_made
          expect(a_get('/1.1/lists/statuses.json').with(query: {count: '200', max_id: '244099460672679937', owner_id: '7505382', slug: 'presidents', include_entities: 'false'})).to have_been_made
        end
      end
    end
    context 'Twitter is down' do
      it 'retries 3 times and then raise an error' do
        stub_get('/1.1/lists/statuses.json').with(query: {count: '200', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'false'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
        expect do
          @search.list('presidents', 'twitter')
        end.to raise_error(Twitter::Error::BadGateway)
        expect(a_get('/1.1/lists/statuses.json').with(query: {count: '200', owner_screen_name: 'testcli', slug: 'presidents', include_entities: 'false'})).to have_been_made.times(3)
      end
    end
  end

  describe '#retweets' do
    before do
      stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244102729860009983', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @search.retweets('mosaic')
      expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'false'})).to have_been_made
      expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244102729860009983', include_entities: 'false'})).to have_been_made.times(2)
    end
    it 'has the correct output' do
      @search.retweets('mosaic')
      expect($stdout.string).to eq <<-EOS
   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

      EOS
    end
    context '--csv' do
      before do
        @search.options = @search.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @search.retweets('mosaic')
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          244108728834592770,2012-09-07 16:23:50 +0000,calebelston,RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
        EOS
      end
    end
    context '--decode-uris' do
      before(:each) do
        @search.options = @search.options.merge('decode_uris' => true)
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244102729860009983', include_entities: 'true'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.retweets('mosaic')
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'true'})).to have_been_made
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244102729860009983', include_entities: 'true'})).to have_been_made.times(2)
      end
      it 'decodes URLs' do
        @search.retweets('mosaic')
        expect($stdout.string).to include 'http://heymosaic.com/i/1Z8ssK'
      end
    end
    context '--long' do
      before do
        @search.options = @search.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @search.retweets('mosaic')
        expect($stdout.string).to eq <<~EOS
          ID                  Posted at     Screen name   Text
          244108728834592770  Sep  7 08:23  @calebelston  RT @olivercameron: Mosaic loo...
        EOS
      end
    end
    context 'Twitter is down' do
      it 'retries 3 times and then raise an error' do
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'false'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
        expect do
          @search.retweets('mosaic')
        end.to raise_error(Twitter::Error::BadGateway)
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'false'})).to have_been_made.times(3)
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', screen_name: 'sferik', max_id: '244102729860009983', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.retweets('sferik', 'mosaic')
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', screen_name: 'sferik', max_id: '244102729860009983', include_entities: 'false'})).to have_been_made.times(2)
      end
      it 'has the correct output' do
        @search.retweets('sferik', 'mosaic')
        expect($stdout.string).to eq <<-EOS
   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

        EOS
      end
      context '--id' do
        before do
          @search.options = @search.options.merge('id' => true)
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', user_id: '7505382', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', user_id: '7505382', max_id: '244102729860009983', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @search.retweets('7505382', 'mosaic')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', user_id: '7505382', include_entities: 'false'})).to have_been_made
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', user_id: '7505382', max_id: '244102729860009983', include_entities: 'false'})).to have_been_made.times(2)
        end
        it 'has the correct output' do
          @search.retweets('7505382', 'mosaic')
          expect($stdout.string).to eq <<-EOS
   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

          EOS
        end
      end
    end
  end

  describe '#timeline' do
    before do
      stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', max_id: '244099460672679937', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @search.timeline('twitter')
      expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made
      expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', max_id: '244099460672679937', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @search.timeline('twitter')
      expect($stdout.string).to eq <<-EOS
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be
   missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

      EOS
    end
    context '--csv' do
      before do
        @search.options = @search.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @search.timeline('twitter')
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
          244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
        EOS
      end
    end
    context '--decode-uris' do
      before(:each) do
        @search.options = @search.options.merge('decode_uris' => true)
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', max_id: '244099460672679937', include_entities: 'true'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.timeline('twitter')
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_entities: 'true'})).to have_been_made
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', max_id: '244099460672679937', include_entities: 'true'})).to have_been_made
      end
      it 'decodes URLs' do
        @search.timeline('twitter')
        expect($stdout.string).to include 'https://dev.twitter.com/docs/api/post/direct_messages/destroy'
      end
    end
    context '--exclude=replies' do
      before do
        @search.options = @search.options.merge('exclude' => 'replies')
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', exclude_replies: 'true', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', exclude_replies: 'true', max_id: '244099460672679937', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'excludes replies' do
        @search.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', exclude_replies: 'true', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', exclude_replies: 'true', max_id: '244099460672679937', include_entities: 'false'})).to have_been_made
      end
    end
    context '--exclude=retweets' do
      before do
        @search.options = @search.options.merge('exclude' => 'retweets')
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_rts: 'false', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_rts: 'false', max_id: '244099460672679937', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'excludes retweets' do
        @search.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_rts: 'false', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_rts: 'false', max_id: '244099460672679937', include_entities: 'false'})).to have_been_made
      end
    end
    context '--long' do
      before do
        @search.options = @search.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @search.timeline('twitter')
        expect($stdout.string).to eq <<~EOS
          ID                  Posted at     Screen name  Text
          244102209942458368  Sep  7 07:57  @sferik      @episod @twitterapi now https:...
          244100411563339777  Sep  7 07:50  @sferik      @episod @twitterapi Did you ca...
        EOS
      end
    end
    context '--max-id' do
      before do
        @search.options = @search.options.merge('max_id' => 244_104_558_433_951_744)
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', max_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.timeline('twitter')
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', max_id: '244104558433951744', include_entities: 'false'})).to have_been_made
      end
    end
    context '--since-id' do
      before do
        @search.options = @search.options.merge('since_id' => 244_104_558_433_951_744)
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', since_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', max_id: '244099460672679937', since_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.timeline('twitter')
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', since_id: '244104558433951744', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', max_id: '244099460672679937', since_id: '244104558433951744', include_entities: 'false'})).to have_been_made
      end
    end
    context 'Twitter is down' do
      it 'retries 3 times and then raise an error' do
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_entities: 'false'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
        expect do
          @search.timeline('twitter')
        end.to raise_error(Twitter::Error::BadGateway)
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made.times(3)
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', max_id: '244099460672679937', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @search.timeline('sferik', 'twitter')
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', max_id: '244099460672679937', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
      end
      it 'has the correct output' do
        @search.timeline('sferik', 'twitter')
        expect($stdout.string).to eq <<-EOS
   @sferik
   @episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be
   missing "1.1" from the URL.

   @sferik
   @episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?

        EOS
      end
      context '--csv' do
        before do
          @search.options = @search.options.merge('csv' => true)
        end
        it 'outputs in CSV format' do
          @search.timeline('sferik', 'twitter')
          expect($stdout.string).to eq <<~EOS
            ID,Posted at,Screen name,Text
            244102209942458368,2012-09-07 15:57:56 +0000,sferik,"@episod @twitterapi now https://t.co/I17jUTu2 and https://t.co/deDu4Hgw seem to be missing ""1.1"" from the URL."
            244100411563339777,2012-09-07 15:50:47 +0000,sferik,@episod @twitterapi Did you catch https://t.co/VHsQvZT0 as well?
          EOS
        end
      end
      context '--id' do
        before do
          @search.options = @search.options.merge('id' => true)
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', user_id: '7505382', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', max_id: '244099460672679937', user_id: '7505382', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @search.timeline('7505382', 'twitter')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', user_id: '7505382', include_entities: 'false'})).to have_been_made
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', max_id: '244099460672679937', user_id: '7505382', include_entities: 'false'})).to have_been_made
        end
      end
      context '--long' do
        before do
          @search.options = @search.options.merge('long' => true)
        end
        it 'outputs in long format' do
          @search.timeline('sferik', 'twitter')
          expect($stdout.string).to eq <<~EOS
            ID                  Posted at     Screen name  Text
            244102209942458368  Sep  7 07:57  @sferik      @episod @twitterapi now https:...
            244100411563339777  Sep  7 07:50  @sferik      @episod @twitterapi Did you ca...
          EOS
        end
      end
      context '--max-id' do
        before do
          @search.options = @search.options.merge('max_id' => 244_104_558_433_951_744)
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', max_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @search.timeline('sferik', 'twitter')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', max_id: '244104558433951744', include_entities: 'false'})).to have_been_made
        end
      end
      context '--since-id' do
        before do
          @search.options = @search.options.merge('since_id' => 244_104_558_433_951_744)
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', since_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', max_id: '244099460672679937', since_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @search.timeline('sferik', 'twitter')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', since_id: '244104558433951744', include_entities: 'false'})).to have_been_made
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', max_id: '244099460672679937', since_id: '244104558433951744', include_entities: 'false'})).to have_been_made
        end
      end
      context 'Twitter is down' do
        it 'retries 3 times and then raise an error' do
          stub_get('/1.1/statuses/user_timeline.json').with(query: {screen_name: 'sferik', count: '200', include_entities: 'false'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
          expect do
            @search.timeline('sferik', 'twitter')
          end.to raise_error(Twitter::Error::BadGateway)
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {screen_name: 'sferik', count: '200', include_entities: 'false'})).to have_been_made.times(3)
        end
      end
    end
  end

  describe '#users' do
    before do
      stub_get('/1.1/users/search.json').with(query: {page: '1', q: 'Erik'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/search.json').with(query: {page: '2', q: 'Erik'}).to_return(body: fixture('empty_array.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @search.users('Erik')
      expect(a_get('/1.1/users/search.json').with(query: {page: '1', q: 'Erik'})).to have_been_made
      expect(a_get('/1.1/users/search.json').with(query: {page: '2', q: 'Erik'})).to have_been_made
    end
    it 'has the correct output' do
      @search.users('Erik')
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @search.options = @search.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @search.users('Erik')
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @search.options = @search.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @search.users('Erik')
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @search.options = @search.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @search.users('Erik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @search.options = @search.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @search.users('Erik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @search.options = @search.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @search.users('Erik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @search.options = @search.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @search.users('Erik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=listed' do
      before do
        @search.options = @search.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @search.users('Erik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @search.options = @search.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter account was created' do
        @search.users('Erik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @search.options = @search.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @search.users('Erik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @search.options = @search.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @search.users('Erik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @search.options = @search.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @search.users('Erik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context 'Twitter is down' do
      it 'retries 3 times and then raise an error' do
        stub_get('/1.1/users/search.json').with(query: {page: '2', q: 'Erik'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
        expect do
          @search.users('Erik')
        end.to raise_error(Twitter::Error::BadGateway)
        expect(a_get('/1.1/users/search.json').with(query: {page: '2', q: 'Erik'})).to have_been_made.times(3)
      end
    end
  end
end
