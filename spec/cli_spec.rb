# encoding: utf-8

require 'helper'

describe T::CLI do
  before :all do
    Timecop.freeze(Time.utc(2011, 11, 24, 16, 20, 0))
    T.utc_offset = 'PST'
  end

  before do
    T::RCFile.instance.path = fixture_path + '/.trc'
    @cli = T::CLI.new
    @cli.options = @cli.options.merge('color' => 'always')
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

  describe '#account' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
    end
    it 'has the correct output' do
      @cli.accounts
      expect($stdout.string).to eq <<~EOS
        testcli
          abc123 (active)
      EOS
    end
  end

  describe '#authorize' do
    before do
      @cli.options = @cli.options.merge('profile' => project_path + '/tmp/authorize', 'display-uri' => true)
      stub_post('/oauth/request_token').to_return(body: fixture('request_token'))
      stub_post('/oauth/access_token').to_return(body: fixture('access_token'))
      stub_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      expect(Readline).to receive(:readline).with('Press [Enter] to open the Twitter Developer site. ', true).and_return("\n")
      expect(Readline).to receive(:readline).with('Enter your API key: ', true).and_return('abc123')
      expect(Readline).to receive(:readline).with('Enter your API secret: ', true).and_return('asdfasd223sd2')
      expect(Readline).to receive(:readline).with('Press [Enter] to open the Twitter app authorization page. ', true).and_return("\n")
      expect(Readline).to receive(:readline).with('Enter the supplied PIN: ', true).and_return('1234567890')
      @cli.authorize
      expect(a_post('/oauth/request_token')).to have_been_made
      expect(a_post('/oauth/access_token')).to have_been_made
      expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
    end
    it 'does not raise error' do
      expect do
        expect(Readline).to receive(:readline).with('Press [Enter] to open the Twitter Developer site. ', true).and_return("\n")
        expect(Readline).to receive(:readline).with('Enter your API key: ', true).and_return('abc123')
        expect(Readline).to receive(:readline).with('Enter your API secret: ', true).and_return('asdfasd223sd2')
        expect(Readline).to receive(:readline).with('Press [Enter] to open the Twitter app authorization page. ', true).and_return("\n")
        expect(Readline).to receive(:readline).with('Enter the supplied PIN: ', true).and_return('1234567890')
        @cli.authorize
      end.not_to raise_error
    end
    context 'empty RC file' do
      before do
        file_path = project_path + '/tmp/empty'
        @cli.options = @cli.options.merge('profile' => file_path, 'display-uri' => true)
      end
      after do
        file_path = project_path + '/tmp/empty'
        File.delete(file_path) if File.exist?(file_path)
      end
      it 'requests the correct resource' do
        expect(Readline).to receive(:readline).with('Press [Enter] to open the Twitter Developer site. ', true).and_return("\n")
        expect(Readline).to receive(:readline).with('Enter your API key: ', true).and_return('abc123')
        expect(Readline).to receive(:readline).with('Enter your API secret: ', true).and_return('asdfasd223sd2')
        expect(Readline).to receive(:readline).with('Press [Enter] to open the Twitter app authorization page. ', true).and_return("\n")
        expect(Readline).to receive(:readline).with('Enter the supplied PIN: ', true).and_return('1234567890')
        @cli.authorize
        expect(a_post('/oauth/request_token')).to have_been_made
        expect(a_post('/oauth/access_token')).to have_been_made
        expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
      end
      it 'does not raise error' do
        expect do
          expect(Readline).to receive(:readline).with('Press [Enter] to open the Twitter Developer site. ', true).and_return("\n")
          expect(Readline).to receive(:readline).with('Enter your API key: ', true).and_return('abc123')
          expect(Readline).to receive(:readline).with('Enter your API secret: ', true).and_return('asdfasd223sd2')
          expect(Readline).to receive(:readline).with('Press [Enter] to open the Twitter app authorization page. ', true).and_return("\n")
          expect(Readline).to receive(:readline).with('Enter the supplied PIN: ', true).and_return('1234567890')
          @cli.authorize
        end.not_to raise_error
      end
    end
  end

  describe '#block' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
      stub_post('/1.1/blocks/create.json').with(body: {screen_name: 'sferik'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.block('sferik')
      expect(a_post('/1.1/blocks/create.json').with(body: {screen_name: 'sferik'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.block('sferik')
      expect($stdout.string).to match(/^@testcli blocked 1 user/)
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_post('/1.1/blocks/create.json').with(body: {user_id: '7505382'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.block('7505382')
        expect(a_post('/1.1/blocks/create.json').with(body: {user_id: '7505382'})).to have_been_made
      end
    end
  end

  describe '#direct_messages' do
    before do
      stub_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'false'}).to_return(body: fixture('direct_message_events.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'false', max_id: '856477710595624962'}).to_return(body: fixture('empty_cursor.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get("/1.1/account/verify_credentials.json").with(query: {skip_status: "true"}).to_return(body: fixture("sferik.json"), headers: {content_type: "application/json; charset=utf-8"})
      stub_get("/1.1/users/lookup.json").with(query: {user_id: '358486183,311650899,422190131,759849327200047104,73660881,328677087,4374876088,2924245126'}).to_return(body: fixture("direct_message_users.json"), headers: {content_type: "application/json; charset=utf-8"})
    end
    it 'requests the correct resource' do
      @cli.direct_messages
      expect(a_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'false'})).to have_been_made
      expect(a_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'false', max_id: '856477710595624962'})).to have_been_made
      expect(a_get("/1.1/account/verify_credentials.json").with(query: {skip_status: "true"})).to have_been_made
      expect(a_get("/1.1/users/lookup.json").with(query: {user_id: '358486183,311650899,422190131,759849327200047104,73660881,328677087,4374876088,2924245126'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.direct_messages
      expect($stdout.string).to eq <<-EOS
   @
   Thanks https://twitter.com/i/stickers/image/10011

   @Araujoselmaa
   ❤️

   @nederfariar
   😍

   @juliawerneckx
   obrigada!!! bj

   @
   https://twitter.com/i/stickers/image/10011

   @marlonscampos
   OBRIGADO MINHA LINDA SERÁ INCRÍVEL ASSISTIR O TEU SHOW, VOU FAZER O POSSÍVEL
   PARA TE PRESTIGIAR. SUCESSO

   @abcss_cesar
   Obrigado. Vou adquiri-lo. Muito sucesso!

   @nederfariar
   COM CERTEZA QDO ESTIVER EM SAO PAUÇO IREI COM O MAIOR PRAZER SUCESSO LINDA

   @Free7Freejac
   😍 Música boa para seu espetáculo em São-Paulo com seu amigo

   @Free7Freejac
   Jardim urbano

   @Free7Freejac
   https://twitter.com/messages/media/856478621090942979

   @Free7Freejac
   Os amantes em face a o mar

   @Free7Freejac
   https://twitter.com/messages/media/856477710595624963

      EOS
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.direct_messages
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          856574281366605831,2017-04-24 18:23:17 +0000,,Thanks https://twitter.com/i/stickers/image/10011
          856571192978927619,2017-04-24 18:11:01 +0000,Araujoselmaa,❤️
          856554872984018948,2017-04-24 17:06:10 +0000,nederfariar,😍
          856538753409703939,2017-04-24 16:02:07 +0000,juliawerneckx,obrigada!!! bj
          856533644445396996,2017-04-24 15:41:49 +0000,, https://twitter.com/i/stickers/image/10011
          856526573545062407,2017-04-24 15:13:43 +0000,marlonscampos,"OBRIGADO MINHA LINDA SERÁ INCRÍVEL ASSISTIR O TEU SHOW, VOU FAZER O POSSÍVEL PARA TE PRESTIGIAR. SUCESSO"
          856516885524951043,2017-04-24 14:35:13 +0000,abcss_cesar,Obrigado. Vou adquiri-lo. Muito sucesso!
          856502352299405315,2017-04-24 13:37:28 +0000,nederfariar,COM CERTEZA QDO ESTIVER EM SAO PAUÇO IREI COM O MAIOR PRAZER SUCESSO LINDA
          856480124421771268,2017-04-24 12:09:08 +0000,Free7Freejac,😍 Música boa para seu espetáculo em São-Paulo com seu amigo
          856478933260410883,2017-04-24 12:04:24 +0000,Free7Freejac,Jardim urbano
          856478621090942979,2017-04-24 12:03:10 +0000,Free7Freejac, https://twitter.com/messages/media/856478621090942979
          856477958885834755,2017-04-24 12:00:32 +0000,Free7Freejac,Os amantes em face a o mar
          856477710595624963,2017-04-24 11:59:33 +0000,Free7Freejac, https://twitter.com/messages/media/856477710595624963
        EOS
      end
    end
    context '--decode-uris' do
      before do
        @cli.options = @cli.options.merge('decode_uris' => true)
        stub_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'true'}).to_return(body: fixture('direct_message_events.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', max_id: '856477710595624962', include_entities: 'true'}).to_return(body: fixture('empty_cursor.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.direct_messages
        expect(a_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'true'})).to have_been_made
        expect(a_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', max_id: '856477710595624962', include_entities: 'true'})).to have_been_made
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.direct_messages
        expect($stdout.string).to eq <<~EOS
          ID                  Posted at     Screen name     Text
          856574281366605831  Apr 24 10:23  @               Thanks https://twitter.com/...
          856571192978927619  Apr 24 10:11  @Araujoselmaa   ❤️
          856554872984018948  Apr 24 09:06  @nederfariar    😍
          856538753409703939  Apr 24 08:02  @juliawerneckx  obrigada!!! bj
          856533644445396996  Apr 24 07:41  @                https://twitter.com/i/stic...
          856526573545062407  Apr 24 07:13  @marlonscampos  OBRIGADO MINHA LINDA SERÁ I...
          856516885524951043  Apr 24 06:35  @abcss_cesar    Obrigado. Vou adquiri-lo. M...
          856502352299405315  Apr 24 05:37  @nederfariar    COM CERTEZA QDO ESTIVER EM ...
          856480124421771268  Apr 24 04:09  @Free7Freejac   😍 Música boa para seu espet...
          856478933260410883  Apr 24 04:04  @Free7Freejac   Jardim urbano
          856478621090942979  Apr 24 04:03  @Free7Freejac    https://twitter.com/messag...
          856477958885834755  Apr 24 04:00  @Free7Freejac   Os amantes em face a o mar
          856477710595624963  Apr 24 03:59  @Free7Freejac    https://twitter.com/messag...
        EOS
      end
    end
    context '--number' do
      before do
        stub_get('/1.1/users/lookup.json').with(query: {user_id: '358486183'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'limits the number of results to 1' do
        @cli.options = @cli.options.merge('number' => 1)
        @cli.direct_messages
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '358486183'})).to have_been_made
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.direct_messages
        expect($stdout.string).to eq <<-EOS
   @Free7Freejac
   https://twitter.com/messages/media/856477710595624963

   @Free7Freejac
   Os amantes em face a o mar

   @Free7Freejac
   https://twitter.com/messages/media/856478621090942979

   @Free7Freejac
   Jardim urbano

   @Free7Freejac
   😍 Música boa para seu espetáculo em São-Paulo com seu amigo

   @nederfariar
   COM CERTEZA QDO ESTIVER EM SAO PAUÇO IREI COM O MAIOR PRAZER SUCESSO LINDA

   @abcss_cesar
   Obrigado. Vou adquiri-lo. Muito sucesso!

   @marlonscampos
   OBRIGADO MINHA LINDA SERÁ INCRÍVEL ASSISTIR O TEU SHOW, VOU FAZER O POSSÍVEL
   PARA TE PRESTIGIAR. SUCESSO

   @
   https://twitter.com/i/stickers/image/10011

   @juliawerneckx
   obrigada!!! bj

   @nederfariar
   😍

   @Araujoselmaa
   ❤️

   @
   Thanks https://twitter.com/i/stickers/image/10011

        EOS
      end
    end
  end

  describe '#direct_messages_sent' do
    before do
      stub_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'false'}).to_return(body: fixture('direct_message_events.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', max_id: '856480385957548034', include_entities: 'false'}).to_return(body: fixture('empty_cursor.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.direct_messages_sent
      expect(a_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.direct_messages_sent
      expect($stdout.string).to eq <<-EOS
   @
   https://twitter.com/i/stickers/image/10018

   @
   https://twitter.com/i/stickers/image/10017

   @
   Obrigada Jacques

      EOS
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.direct_messages_sent
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          856523843892129796,2017-04-24 15:02:52 +0000,, https://twitter.com/i/stickers/image/10018
          856523768910544899,2017-04-24 15:02:34 +0000,, https://twitter.com/i/stickers/image/10017
          856480385957548035,2017-04-24 12:10:11 +0000,,Obrigada Jacques
        EOS
      end
    end
    context '--decode-uris' do
      before do
        @cli.options = @cli.options.merge('decode_uris' => true)
        stub_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'true'}).to_return(body: fixture('direct_message_events.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', max_id: '856480385957548034', include_entities: 'true'}).to_return(body: fixture('empty_cursor.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.direct_messages_sent
        expect(a_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'true'})).to have_been_made
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.direct_messages_sent
        expect($stdout.string).to eq <<~EOS
          ID                  Posted at     Screen name  Text
          856523843892129796  Apr 24 07:02  @             https://twitter.com/i/sticker...
          856523768910544899  Apr 24 07:02  @             https://twitter.com/i/sticker...
          856480385957548035  Apr 24 04:10  @            Obrigada Jacques
        EOS
      end
    end
    context '--number' do
      it 'limits the number of results 1' do
        @cli.options = @cli.options.merge('number' => 1)
        @cli.direct_messages_sent
        expect(a_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'false'})).to have_been_made
      end
      it 'limits the number of results to 201' do
        @cli.options = @cli.options.merge('number' => 201)
        @cli.direct_messages_sent
        expect(a_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/direct_messages/events/list.json').with(query: {count: '50', max_id: '856480385957548034', include_entities: 'false'})).to have_been_made
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.direct_messages_sent
        expect($stdout.string).to eq <<-EOS
   @
   Obrigada Jacques

   @
   https://twitter.com/i/stickers/image/10017

   @
   https://twitter.com/i/stickers/image/10018

        EOS
      end
    end
  end

  describe '#dm' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
      stub_post('/1.1/direct_messages/events/new.json').with(body: {event: {type: 'message_create', message_create: {target: {recipient_id: 7505382}, message_data: {text: 'Creating a fixture for the Twitter gem'}}}}).to_return(body: fixture('direct_message_event.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/show.json').with(query: {screen_name: 'sferik'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.dm('sferik', 'Creating a fixture for the Twitter gem')
      expect(a_post('/1.1/direct_messages/events/new.json').with(body: {event: {type: 'message_create', message_create: {target: {recipient_id: 7505382}, message_data: {text: 'Creating a fixture for the Twitter gem'}}}})).to have_been_made
      expect(a_get('/1.1/users/show.json').with(query: {screen_name: 'sferik'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.dm('sferik', 'Creating a fixture for the Twitter gem')
      expect($stdout.string.chomp).to eq 'Direct Message sent from @testcli to @sferik.'
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_post('/1.1/direct_messages/events/new.json').with(body: {event: {type: 'message_create', message_create: {target: {recipient_id: 7505382}, message_data: {text: 'Creating a fixture for the Twitter gem'}}}}).to_return(body: fixture('direct_message_event.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/users/show.json').with(query: {user_id: '7505382'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.dm('7505382', 'Creating a fixture for the Twitter gem')
        expect(a_post('/1.1/direct_messages/events/new.json').with(body: {event: {type: 'message_create', message_create: {target: {recipient_id: 7505382}, message_data: {text: 'Creating a fixture for the Twitter gem'}}}})).to have_been_made
        expect(a_get('/1.1/users/show.json').with(query: {user_id: '7505382'})).to have_been_made
      end
      it 'has the correct output' do
        @cli.dm('7505382', 'Creating a fixture for the Twitter gem')
        expect($stdout.string.chomp).to eq 'Direct Message sent from @testcli to @sferik.'
      end
    end
  end

  describe '#does_contain' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
      stub_get('/1.1/lists/members/show.json').with(query: {owner_screen_name: 'testcli', screen_name: 'testcli', slug: 'presidents'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.does_contain('presidents')
      expect(a_get('/1.1/lists/members/show.json').with(query: {owner_screen_name: 'testcli', screen_name: 'testcli', slug: 'presidents'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.does_contain('presidents')
      expect($stdout.string.chomp).to eq 'Yes, presidents contains @testcli.'
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_get('/1.1/users/show.json').with(query: {user_id: '7505382'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/lists/members/show.json').with(query: {owner_screen_name: 'testcli', screen_name: 'sferik', slug: 'presidents'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.does_contain('presidents', '7505382')
        expect(a_get('/1.1/users/show.json').with(query: {user_id: '7505382'})).to have_been_made
        expect(a_get('/1.1/lists/members/show.json').with(query: {owner_screen_name: 'testcli', screen_name: 'sferik', slug: 'presidents'})).to have_been_made
      end
    end
    context 'with an owner passed' do
      it 'has the correct output' do
        @cli.does_contain('testcli/presidents', 'testcli')
        expect($stdout.string.chomp).to eq 'Yes, presidents contains @testcli.'
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/users/show.json').with(query: {user_id: '7505382'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/lists/members/show.json').with(query: {owner_id: '7505382', screen_name: 'sferik', slug: 'presidents'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.does_contain('7505382/presidents', '7505382')
          expect(a_get('/1.1/users/show.json').with(query: {user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/lists/members/show.json').with(query: {owner_id: '7505382', screen_name: 'sferik', slug: 'presidents'})).to have_been_made
        end
      end
    end
    context 'with a user passed' do
      it 'has the correct output' do
        @cli.does_contain('presidents', 'testcli')
        expect($stdout.string.chomp).to eq 'Yes, presidents contains @testcli.'
      end
    end
    context 'false' do
      before do
        stub_get('/1.1/lists/members/show.json').with(query: {owner_screen_name: 'testcli', screen_name: 'testcli', slug: 'presidents'}).to_return(body: fixture('not_found.json'), status: 404, headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'exits' do
        expect do
          @cli.does_contain('presidents')
        end.to raise_error(SystemExit)
        expect(a_get('/1.1/lists/members/show.json').with(query: {owner_screen_name: 'testcli', screen_name: 'testcli', slug: 'presidents'})).to have_been_made
      end
    end
  end

  describe '#does_follow' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
      stub_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'ev', target_screen_name: 'testcli'}).to_return(body: fixture('following.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.does_follow('ev')
      expect(a_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'ev', target_screen_name: 'testcli'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.does_follow('ev')
      expect($stdout.string.chomp).to eq 'Yes, @ev follows @testcli.'
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_get('/1.1/users/show.json').with(query: {user_id: '20'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'sferik', target_screen_name: 'testcli'}).to_return(body: fixture('following.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.does_follow('20')
        expect(a_get('/1.1/users/show.json').with(query: {user_id: '20'})).to have_been_made
        expect(a_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'sferik', target_screen_name: 'testcli'})).to have_been_made
      end
      it 'has the correct output' do
        @cli.does_follow('20')
        expect($stdout.string.chomp).to eq 'Yes, @sferik follows @testcli.'
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'ev', target_screen_name: 'sferik'}).to_return(body: fixture('following.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.does_follow('ev', 'sferik')
        expect(a_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'ev', target_screen_name: 'sferik'})).to have_been_made
      end
      it 'has the correct output' do
        @cli.does_follow('ev', 'sferik')
        expect($stdout.string.chomp).to eq 'Yes, @ev follows @sferik.'
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/users/show.json').with(query: {user_id: '20'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/users/show.json').with(query: {user_id: '428004849'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'sferik', target_screen_name: 'sferik'}).to_return(body: fixture('following.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.does_follow('20', '428004849')
          expect(a_get('/1.1/users/show.json').with(query: {user_id: '20'})).to have_been_made
          expect(a_get('/1.1/users/show.json').with(query: {user_id: '428004849'})).to have_been_made
          expect(a_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'sferik', target_screen_name: 'sferik'})).to have_been_made
        end
        it 'has the correct output' do
          @cli.does_follow('20', '428004849')
          expect($stdout.string.chomp).to eq 'Yes, @sferik follows @sferik.'
        end
        it 'cannot follow yourself' do
          expect do
            @cli.does_follow 'testcli'
            expect($stderr.string.chomp).to eq 'No, you are not following yourself.'
          end.to raise_error(SystemExit)
        end
        it 'cannot check same account' do
          expect do
            @cli.does_follow('sferik', 'sferik')
            expect($stderr.string.chomp).to eq 'No, @sferik is not following themself.'
          end.to raise_error(SystemExit)
        end
      end
    end
    context 'false' do
      before do
        stub_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'ev', target_screen_name: 'testcli'}).to_return(body: fixture('not_following.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'exits' do
        expect do
          @cli.does_follow('ev')
        end.to raise_error(SystemExit)
        expect(a_get('/1.1/friendships/show.json').with(query: {source_screen_name: 'ev', target_screen_name: 'testcli'})).to have_been_made
      end
    end
  end

  describe '#favorite' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
      stub_post('/1.1/favorites/create.json').with(body: {id: '26755176471724032'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.favorite('26755176471724032')
      expect(a_post('/1.1/favorites/create.json').with(body: {id: '26755176471724032'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.favorite('26755176471724032')
      expect($stdout.string).to match(/^@testcli favorited 1 tweet.$/)
    end
  end

  describe '#favorites' do
    before do
      stub_get('/1.1/favorites/list.json').with(query: {count: '20', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.favorites
      expect(a_get('/1.1/favorites/list.json').with(query: {count: '20', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.favorites
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
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.favorites
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
        @cli.options = @cli.options.merge('decode_uris' => true)
        stub_get('/1.1/favorites/list.json').with(query: {count: '20', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.favorites
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '20', include_entities: 'true'})).to have_been_made
      end
      it 'decodes URLs' do
        @cli.favorites
        expect($stdout.string).to include 'https://twitter.com/sferik/status/243988000076337152'
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.favorites
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
          @cli.options = @cli.options.merge('reverse' => true)
        end
        it 'reverses the order of the sort' do
          @cli.favorites
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
    context '--max-id' do
      before do
        @cli.options = @cli.options.merge('max_id' => 244_104_558_433_951_744)
        stub_get('/1.1/favorites/list.json').with(query: {count: '20', max_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.favorites
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '20', max_id: '244104558433951744', include_entities: 'false'})).to have_been_made
      end
    end
    context '--number' do
      before do
        stub_get('/1.1/favorites/list.json').with(query: {count: '1', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'false'}).to_return(body: fixture('200_statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/favorites/list.json').with(query: {count: '1', max_id: '265500541700956160', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'limits the number of results to 1' do
        @cli.options = @cli.options.merge('number' => 1)
        @cli.favorites
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '1', include_entities: 'false'})).to have_been_made
      end
      it 'limits the number of results to 201' do
        @cli.options = @cli.options.merge('number' => 201)
        @cli.favorites
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '1', max_id: '265500541700956160', include_entities: 'false'})).to have_been_made
      end
    end
    context '--since-id' do
      before do
        @cli.options = @cli.options.merge('since_id' => 244_104_558_433_951_744)
        stub_get('/1.1/favorites/list.json').with(query: {count: '20', since_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.favorites
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '20', since_id: '244104558433951744', include_entities: 'false'})).to have_been_made
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/favorites/list.json').with(query: {count: '20', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.favorites('sferik')
        expect(a_get('/1.1/favorites/list.json').with(query: {count: '20', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/favorites/list.json').with(query: {user_id: '7505382', count: '20', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.favorites('7505382')
          expect(a_get('/1.1/favorites/list.json').with(query: {user_id: '7505382', count: '20', include_entities: 'false'})).to have_been_made
        end
      end
      context '--max-id' do
        before do
          @cli.options = @cli.options.merge('max_id' => 244_104_558_433_951_744)
          stub_get('/1.1/favorites/list.json').with(query: {count: '20', screen_name: 'sferik', max_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.favorites('sferik')
          expect(a_get('/1.1/favorites/list.json').with(query: {count: '20', screen_name: 'sferik', max_id: '244104558433951744', include_entities: 'false'})).to have_been_made
        end
      end
      context '--number' do
        before do
          stub_get('/1.1/favorites/list.json').with(query: {count: '1', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/favorites/list.json').with(query: {count: '200', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('200_statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/favorites/list.json').with(query: {count: '1', screen_name: 'sferik', max_id: '265500541700956160', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'limits the number of results to 1' do
          @cli.options = @cli.options.merge('number' => 1)
          @cli.favorites('sferik')
          expect(a_get('/1.1/favorites/list.json').with(query: {count: '1', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
        end
        it 'limits the number of results to 201' do
          @cli.options = @cli.options.merge('number' => 201)
          @cli.favorites('sferik')
          expect(a_get('/1.1/favorites/list.json').with(query: {count: '200', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
          expect(a_get('/1.1/favorites/list.json').with(query: {count: '1', screen_name: 'sferik', max_id: '265500541700956160', include_entities: 'false'})).to have_been_made
        end
      end
      context '--since-id' do
        before do
          @cli.options = @cli.options.merge('since_id' => 244_104_558_433_951_744)
          stub_get('/1.1/favorites/list.json').with(query: {count: '20', screen_name: 'sferik', since_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.favorites('sferik')
          expect(a_get('/1.1/favorites/list.json').with(query: {count: '20', screen_name: 'sferik', since_id: '244104558433951744', include_entities: 'false'})).to have_been_made
        end
      end
    end
  end

  describe '#follow' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
    end
    context 'one user' do
      before do
        stub_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/users/lookup.json').with(query: {screen_name: 'sferik,pengwynn'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_post('/1.1/friendships/create.json').with(body: {user_id: '14100886'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.follow('sferik', 'pengwynn')
        expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
        expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {screen_name: 'sferik,pengwynn'})).to have_been_made
        expect(a_post('/1.1/friendships/create.json').with(body: {user_id: '14100886'})).to have_been_made
      end
      it 'has the correct output' do
        @cli.follow('sferik', 'pengwynn')
        expect($stdout.string).to match(/^@testcli is now following 1 more user\.$/)
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/users/lookup.json').with(query: {user_id: '7505382,14100886'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_post('/1.1/friendships/create.json').with(body: {user_id: '14100886'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.follow('7505382', '14100886')
          expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382,14100886'})).to have_been_made
          expect(a_post('/1.1/friendships/create.json').with(body: {user_id: '14100886'})).to have_been_made
        end
      end
      context 'Twitter is down' do
        it 'retries 3 times and then raise an error' do
          stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/users/lookup.json').with(query: {screen_name: 'sferik,pengwynn'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_post('/1.1/friendships/create.json').with(body: {user_id: '14100886'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
          expect do
            @cli.follow('sferik', 'pengwynn')
          end.to raise_error(Twitter::Error::BadGateway)
          expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made.times(3)
          expect(a_get('/1.1/users/lookup.json').with(query: {screen_name: 'sferik,pengwynn'})).to have_been_made.times(3)
          expect(a_post('/1.1/friendships/create.json').with(body: {user_id: '14100886'})).to have_been_made.times(3)
        end
      end
    end
  end

  describe '#followings' do
    before do
      stub_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.followings
      expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
      expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
      expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.followings
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.followings
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.followings
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.followings
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @cli.options = @cli.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @cli.followings
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @cli.options = @cli.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @cli.followings
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @cli.options = @cli.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @cli.followings
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=listed' do
      before do
        @cli.options = @cli.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @cli.followings
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @cli.options = @cli.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter acount was created' do
        @cli.followings
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @cli.followings
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @cli.followings
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.followings
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.followings('sferik')
        expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
      end
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.followings('7505382')
        expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
      end
    end
  end

  describe '#followings_following' do
    before do
      stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'testcli'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.followings_following('sferik')
      expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'testcli'})).to have_been_made
      expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
      expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.followings_following('sferik')
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.followings_following('sferik')
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.followings_following('sferik')
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.followings_following('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @cli.options = @cli.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @cli.followings_following('sferik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @cli.options = @cli.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @cli.followings_following('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @cli.options = @cli.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @cli.followings_following('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=listed' do
      before do
        @cli.options = @cli.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @cli.followings_following('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @cli.options = @cli.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter acount was created' do
        @cli.followings_following('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @cli.followings_following('sferik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @cli.followings_following('sferik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.followings_following('sferik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context 'with two users passed' do
      before do
        stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'pengwynn'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.followings_following('sferik', 'pengwynn')
        expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'pengwynn'})).to have_been_made
        expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '14100886'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.followings_following('7505382', '14100886')
          expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '14100886'})).to have_been_made
          expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
        end
      end
    end
  end

  describe '#followers' do
    before do
      stub_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.followers
      expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
      expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
      expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.followers
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.followers
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.followers
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.followers
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @cli.options = @cli.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @cli.followers
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @cli.options = @cli.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @cli.followers
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @cli.options = @cli.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @cli.followers
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=listed' do
      before do
        @cli.options = @cli.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @cli.followers
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @cli.options = @cli.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter acount was created' do
        @cli.followers
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @cli.followers
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @cli.followers
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.followers
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/users/lookup.json').with(query: {user_id: '213747670,428004849'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.followers('sferik')
        expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.followers('7505382')
          expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
        end
      end
    end
  end

  describe '#friends' do
    before do
      stub_get('/1.1/account/verify_credentials.json').to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.friends
      expect(a_get('/1.1/account/verify_credentials.json')).to have_been_made
      expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
      expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
      expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.friends
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.friends
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.friends
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.friends
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @cli.options = @cli.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @cli.friends
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @cli.options = @cli.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @cli.friends
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @cli.options = @cli.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @cli.friends
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=listed' do
      before do
        @cli.options = @cli.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @cli.friends
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @cli.options = @cli.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter acount was created' do
        @cli.friends
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @cli.friends
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @cli.friends
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.friends
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.friends('sferik')
        expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.friends('7505382')
          expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
        end
      end
    end
  end

  describe '#groupies' do
    before do
      stub_get('/1.1/account/verify_credentials.json').to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/lookup.json').with(query: {user_id: '213747670,428004849'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.groupies
      expect(a_get('/1.1/account/verify_credentials.json')).to have_been_made
      expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
      expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
      expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '213747670,428004849'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.groupies
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.groupies
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.groupies
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.groupies
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @cli.options = @cli.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @cli.groupies
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @cli.options = @cli.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @cli.groupies
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @cli.options = @cli.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @cli.groupies
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=listed' do
      before do
        @cli.options = @cli.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @cli.groupies
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @cli.options = @cli.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter acount was created' do
        @cli.groupies
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @cli.groupies
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @cli.groupies
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.groupies
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.groupies('sferik')
        expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '213747670,428004849'})).to have_been_made
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.groupies('7505382')
          expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '213747670,428004849'})).to have_been_made
        end
      end
    end
  end

  describe '#intersection' do
    before do
      @cli.options = @cli.options.merge('type' => 'followings')
      stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'testcli'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.intersection('sferik')
      expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'testcli'})).to have_been_made
      expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
      expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.intersection('sferik')
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.intersection('sferik')
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.intersection('sferik')
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @cli.options = @cli.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @cli.options = @cli.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @cli.options = @cli.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=listed' do
      before do
        @cli.options = @cli.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @cli.options = @cli.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter acount was created' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--type=followers' do
      before do
        @cli.options = @cli.options.merge('type' => 'followers')
        stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'testcli'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/users/lookup.json').with(query: {user_id: '213747670,428004849'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.intersection('sferik')
        expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'testcli'})).to have_been_made
        expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '213747670,428004849'})).to have_been_made
      end
      it 'has the correct output' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.intersection('sferik')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context 'with two users passed' do
      before do
        stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'pengwynn'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.intersection('sferik', 'pengwynn')
        expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'pengwynn'})).to have_been_made
        expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '14100886'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.intersection('7505382', '14100886')
          expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '14100886'})).to have_been_made
          expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
        end
      end
    end
  end

  describe '#leaders' do
    before do
      stub_get('/1.1/account/verify_credentials.json').to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.leaders
      expect(a_get('/1.1/account/verify_credentials.json')).to have_been_made
      expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
      expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
      expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.leaders
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.leaders
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.leaders
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.leaders
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @cli.options = @cli.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @cli.leaders
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @cli.options = @cli.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @cli.leaders
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @cli.options = @cli.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @cli.leaders
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=listed' do
      before do
        @cli.options = @cli.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @cli.leaders
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @cli.options = @cli.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter acount was created' do
        @cli.leaders
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @cli.leaders
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @cli.leaders
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.leaders
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.leaders('sferik')
        expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', screen_name: 'sferik'})).to have_been_made
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('friends_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.leaders('7505382')
          expect(a_get('/1.1/friends/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
          expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382'})).to have_been_made
        end
      end
    end
  end

  describe '#lists' do
    before do
      stub_get('/1.1/lists/list.json').to_return(body: fixture('lists.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.lists
      expect(a_get('/1.1/lists/list.json')).to have_been_made
    end
    it 'has the correct output' do
      @cli.lists
      expect($stdout.string.chomp).to eq '@pengwynn/rubyists  @twitter/team       @sferik/test'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.lists
        expect($stdout.string).to eq <<~EOS
          ID,Created at,Screen name,Slug,Members,Subscribers,Mode,Description
          1129440,2009-10-30 14:39:25 +0000,pengwynn,rubyists,499,39,public,
          574,2009-09-23 01:18:01 +0000,twitter,team,1199,78078,other,
          73546689,2012-07-08 22:19:05 +0000,sferik,test,2,0,private,
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.lists
        expect($stdout.string).to eq <<~EOS
          ID        Created at    Screen name  Slug      Members  Subscribers  Mode    ...
           1129440  Oct 30  2009  @pengwynn    rubyists      499           39  public   
               574  Sep 22  2009  @twitter     team         1199        78078  other    
          73546689  Jul  8 14:19  @sferik      test            2            0  private  
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.lists
        expect($stdout.string.chomp).to eq '@sferik/test        @twitter/team       @pengwynn/rubyists'
      end
    end
    context '--sort=members' do
      before do
        @cli.options = @cli.options.merge('sort' => 'members')
      end
      it 'sorts by the number of members' do
        @cli.lists
        expect($stdout.string.chomp).to eq '@sferik/test        @pengwynn/rubyists  @twitter/team'
      end
    end
    context '--sort=mode' do
      before do
        @cli.options = @cli.options.merge('sort' => 'mode')
      end
      it 'sorts by the mode' do
        @cli.lists
        expect($stdout.string.chomp).to eq '@twitter/team       @sferik/test        @pengwynn/rubyists'
      end
    end
    context '--sort=since' do
      before do
        @cli.options = @cli.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter list was created' do
        @cli.lists
        expect($stdout.string.chomp).to eq '@twitter/team       @pengwynn/rubyists  @sferik/test'
      end
    end
    context '--sort=subscribers' do
      before do
        @cli.options = @cli.options.merge('sort' => 'subscribers')
      end
      it 'sorts by the number of subscribers' do
        @cli.lists
        expect($stdout.string.chomp).to eq '@sferik/test        @pengwynn/rubyists  @twitter/team'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.lists
        expect($stdout.string.chomp).to eq '@pengwynn/rubyists  @twitter/team       @sferik/test'
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/lists/list.json').with(query: {screen_name: 'sferik'}).to_return(body: fixture('lists.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.lists('sferik')
        expect(a_get('/1.1/lists/list.json').with(query: {screen_name: 'sferik'})).to have_been_made
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/lists/list.json').with(query: {user_id: '7505382'}).to_return(body: fixture('lists.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.lists('7505382')
          expect(a_get('/1.1/lists/list.json').with(query: {user_id: '7505382'})).to have_been_made
        end
      end
    end
  end

  describe '#matrix' do
    before do
      stub_get('/1.1/search/tweets.json').with(query: {q: 'lang:ja', count: 100, include_entities: 'false'}).to_return(body: fixture('matrix.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/search/tweets.json').with(query: {q: 'lang:ja', count: 100, max_id: '434642935557021697', include_entities: 'false'}).to_return(body: fixture('empty_cursor.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.matrix
      expect(a_get('/1.1/search/tweets.json').with(query: {q: 'lang:ja', count: 100, include_entities: 'false'})).to have_been_made
      expect(a_get('/1.1/search/tweets.json').with(query: {q: 'lang:ja', count: 100, max_id: '434642935557021697', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.matrix
      expect($stdout.string).to eq('すまてっんさすでらなるあでかんせまいるきでいおすでいたりにずらさなもはういとざいうよいなしにいおでんせまてっはもらかのはにののずらかかるれらけでついらかがはがすでろこといたいとにいおにばらなくいばれたあんゃちあさかじましたあいしのくうよめやのうとこういうそたみてっがんくをまさかうょしでのるれくていでいてってっねよるれなくとのもなんみばれなくとのがいななんそよいなくしてしかんけでのとのいいゃちめ　んくけったっだもどけるあはえたっあてっのやににめたのあたっかしこそあしだうそもなねうろだんるなになとっもらたてっにもしもるうおんぶたすまりなにはにかいちんゃにぃちほでいなしにのいいばれしことななんみわだいわこま　　いたきのわふわっふくじたすましらかいならわたでんびにでれそんけやなかのたっゃちしとかよたてちにのねいさだくてきすましにりぱっやにいつがたしまりあはろことうろいろいあまねんもだにうとがりあいなてえかしとこたれらててれさてれさてれさきはいなてえうなるがゃちっめつっおいばやらかたてっすでのいばやいばやまんほねよすでかだんなかたしでうそりはやいわかりきっすしがんせまりあはでのていつにのなかのいなはにいらくるがなもとまてめせるけぬしをるすいならをるすいなてめじなにずらわかかもにのなとんにあにあてうゃちんさばおよすでてくなゃじすではのるてっがんさがすましででのいなおはてっあがつやるすにいたみをるあのとのるでいなきでかしではんくどんえっへすでみらたぎすらかんさのらかれこかすでるけべとっずをねいさだくでんにでのなびなんそてんなだねるめたかとこのせゆるねいがすさたっかはのこいなえりあぇふっぇふっぇふいらくとだらかだいらくでいたみゃちっめっもはてくないくしてっやのゆこそこきとなんこういてみのたしねどけうといぞうどるえもでんなででのみるぐいぬでさのでででべなきでききでるてっでぬいねもでくつりがのうよしうどいなくたきうもわこのだねすでうそええいなえかしおらかてっとおよだのいがのてっなくないがういとだぎゃじなをたっかなえとおでまだんでんをのてきてちおらかかったっかなくきのけにいたけにをいなえかしにでてべすのいらくれそできがにももいたりをのそるえうそとたっかよにとこたえにえかすまりかわかるいてっがすまいでんがいながすでのるすをいむにのるすのるいていかをたまてっよにくいてっがらかりすうよたれさにまさいながいのとのるてったいとっょちぜだんなつやいいるてっなにとこなてれがのそっくみいたきいるあではにずはいがりよえかちてしとにせらがにでたえばつにでのるすをれことんほ　いのと　すがるかわるてしはのてんないならをれあるあがぁぁぁぐっっべやかえねゃじんすらなれこよてままいがとれそねよいもれそぱっやをいいねてしごをいしうとがりあもうとがりあもいさゃにみすやおいまうがのすましいおばろぉふらたっかよすまきだたいてせさろぉふすまいざごうとがりあのたしまりなくすできらかいのこたみていかたてってっいたみていにすまいざごうよはおすではつつらからかうもちっこうそあわうたっへこどにでとるぎすなんみがのうよてしのかはのいがかだとみゃしくにうよすまりあでるれでがのにのたっやいてっらこいによはらかだたっかなかついかしいらくいえてえかすまてっでねすでりえかおよたっゃちっいさなんめごたしあうろやでらながっええたしましうとがりあうろをできいさなみすやおるらがなえをいなのくべるなかうこでういうどのでかしつかはてさいばやはれそいばやいばやんらまたんらまたうもらかやきたっかとんほいめやおいなけでどけいたき')
    end
  end

  describe '#mentions' do
    before do
      stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '20', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.mentions
      expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '20', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.mentions
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
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.mentions
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
        @cli.options = @cli.options.merge('decode_uris' => true)
        stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '20', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.mentions
        expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '20', include_entities: 'true'})).to have_been_made
      end
      it 'decodes URLs' do
        @cli.mentions
        expect($stdout.string).to include 'https://twitter.com/sferik/status/243988000076337152'
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.mentions
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
          @cli.options = @cli.options.merge('reverse' => true)
        end
        it 'reverses the order of the sort' do
          @cli.mentions
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
        stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '1', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'false'}).to_return(body: fixture('200_statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '1', max_id: '265500541700956160', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'limits the number of results to 1' do
        @cli.options = @cli.options.merge('number' => 1)
        @cli.mentions
        expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '1', include_entities: 'false'})).to have_been_made
      end
      it 'limits the number of results to 201' do
        @cli.options = @cli.options.merge('number' => 201)
        @cli.mentions
        expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/mentions_timeline.json').with(query: {count: '1', max_id: '265500541700956160', include_entities: 'false'})).to have_been_made
      end
    end
  end

  describe '#mute' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
      stub_post('/1.1/mutes/users/create.json').with(body: {screen_name: 'sferik'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.mute('sferik')
      expect(a_post('/1.1/mutes/users/create.json').with(body: {screen_name: 'sferik'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.mute('sferik')
      expect($stdout.string).to match(/^@testcli muted 1 user/)
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_post('/1.1/mutes/users/create.json').with(body: {user_id: '7505382'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.mute('7505382')
        expect(a_post('/1.1/mutes/users/create.json').with(body: {user_id: '7505382'})).to have_been_made
      end
    end
  end

  describe '#muted' do
    before do
      stub_get('/1.1/mutes/users/ids.json').with(query: {cursor: '-1'}).to_return(body: fixture('muted_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/lookup.json').with(query: {user_id: '14098423'}).to_return(body: fixture('muted_users.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.muted
      expect(a_get('/1.1/mutes/users/ids.json').with(query: {cursor: '-1'})).to have_been_made
      expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '14098423'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.muted
      expect($stdout.string.chomp).to eq 'johndbritton'
    end
  end

  describe '#open' do
    before do
      @cli.options = @cli.options.merge('display-uri' => true)
    end
    it 'has the correct output' do
      expect do
        @cli.open('sferik')
      end.not_to raise_error
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_get('/1.1/users/show.json').with(query: {user_id: '420'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.open('420')
        expect(a_get('/1.1/users/show.json').with(query: {user_id: '420'})).to have_been_made
      end
    end
    context '--status' do
      before do
        @cli.options = @cli.options.merge('status' => true)
        stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.open('55709764298092545')
        expect(a_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false'})).to have_been_made
      end
      it 'has the correct output' do
        expect do
          @cli.open('55709764298092545')
        end.not_to raise_error
      end
    end
  end

  describe '#reach' do
    before do
      stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/statuses/retweeters/ids.json').with(query: {id: '55709764298092545', cursor: '-1'}).to_return(body: fixture('ids_list.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/statuses/retweeters/ids.json').with(query: {id: '55709764298092545', cursor: '1305102810874389703'}).to_return(body: fixture('ids_list2.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '20009713'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '14100886'}).to_return(body: fixture('followers_ids.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resources' do
      @cli.reach('55709764298092545')
      expect(a_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false'})).to have_been_made
      expect(a_get('/1.1/statuses/retweeters/ids.json').with(query: {id: '55709764298092545', cursor: '-1'})).to have_been_made
      expect(a_get('/1.1/statuses/retweeters/ids.json').with(query: {id: '55709764298092545', cursor: '1305102810874389703'})).to have_been_made
      expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '7505382'})).to have_been_made
      expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '20009713'})).to have_been_made
      expect(a_get('/1.1/followers/ids.json').with(query: {cursor: '-1', user_id: '14100886'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.reach('55709764298092545')
      expect($stdout.string.split("\n").first).to eq '2'
    end
  end

  describe '#reply' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc', 'location' => nil)
      stub_get('/1.1/statuses/show/263813522369159169.json').with(query: {include_my_retweet: 'false'}).to_return(body: fixture('status_with_mention.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_post('/1.1/statuses/update.json').with(body: {in_reply_to_status_id: '263813522369159169', status: '@joshfrench Testing', trim_user: 'true'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_request(:get, 'http://checkip.dyndns.org/').to_return(body: fixture('checkip.html'), headers: {content_type: 'text/html'})
      stub_request(:get, 'http://www.geoplugin.net/xml.gp?ip=50.131.22.169').to_return(body: fixture('geoplugin.xml'), headers: {content_type: 'application/xml'})
    end
    it 'requests the correct resource' do
      @cli.reply('263813522369159169', 'Testing')
      expect(a_get('/1.1/statuses/show/263813522369159169.json').with(query: {include_my_retweet: 'false'})).to have_been_made
      expect(a_post('/1.1/statuses/update.json').with(body: {in_reply_to_status_id: '263813522369159169', status: '@joshfrench Testing', trim_user: 'true'})).to have_been_made
      expect(a_request(:get, 'http://checkip.dyndns.org/')).not_to have_been_made
      expect(a_request(:get, 'http://www.geoplugin.net/xml.gp?ip=50.131.22.169')).not_to have_been_made
    end
    it 'has the correct output' do
      @cli.reply('263813522369159169', 'Testing')
      expect($stdout.string.split("\n").first).to eq 'Reply posted by @testcli to @joshfrench.'
    end
    context '--all' do
      before do
        @cli.options = @cli.options.merge('all' => true)
        stub_post('/1.1/statuses/update.json').with(body: {in_reply_to_status_id: '263813522369159169', status: '@joshfrench @sferik Testing', trim_user: 'true'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.reply('263813522369159169', 'Testing')
        expect(a_get('/1.1/statuses/show/263813522369159169.json').with(query: {include_my_retweet: 'false'})).to have_been_made
        expect(a_post('/1.1/statuses/update.json').with(body: {in_reply_to_status_id: '263813522369159169', status: '@joshfrench @sferik Testing', trim_user: 'true'})).to have_been_made
        expect(a_request(:get, 'http://checkip.dyndns.org/')).not_to have_been_made
        expect(a_request(:get, 'http://www.geoplugin.net/xml.gp?ip=50.131.22.169')).not_to have_been_made
      end
      it 'has the correct output' do
        @cli.reply('263813522369159169', 'Testing')
        expect($stdout.string.split("\n").first).to eq 'Reply posted by @testcli to @joshfrench @sferik.'
      end
    end
    context 'with file' do
      before do
        @cli.options = @cli.options.merge('file' => fixture_path + '/long.png')
        stub_request(:post, 'https://upload.twitter.com/1.1/media/upload.json').to_return(body: fixture('upload.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_post('/1.1/statuses/update.json').to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.reply('263813522369159169', 'Testing')
        expect(a_request(:post, 'https://upload.twitter.com/1.1/media/upload.json')).to have_been_made
        expect(a_post('/1.1/statuses/update.json')).to have_been_made
      end
      it 'has the correct output' do
        @cli.reply('263813522369159169', 'Testing')
        expect($stdout.string.split("\n").first).to eq 'Reply posted by @testcli to @joshfrench.'
      end
    end
    context '--location' do
      before do
        @cli.options = @cli.options.merge('location' => 'location')
        stub_get('/1.1/statuses/show/263813522369159169.json').with(query: {include_my_retweet: 'false'}).to_return(body: fixture('status_with_mention.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_post('/1.1/statuses/update.json').with(body: {in_reply_to_status_id: '263813522369159169', status: '@joshfrench Testing', lat: '37.76969909668', long: '-122.39330291748', trim_user: 'true'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.reply('263813522369159169', 'Testing')
        expect(a_get('/1.1/statuses/show/263813522369159169.json').with(query: {include_my_retweet: 'false'})).to have_been_made
        expect(a_post('/1.1/statuses/update.json').with(body: {in_reply_to_status_id: '263813522369159169', status: '@joshfrench Testing', lat: '37.76969909668', long: '-122.39330291748', trim_user: 'true'})).to have_been_made
        expect(a_request(:get, 'http://checkip.dyndns.org/')).to have_been_made
        expect(a_request(:get, 'http://www.geoplugin.net/xml.gp?ip=50.131.22.169')).to have_been_made
      end
      it 'has the correct output' do
        @cli.reply('263813522369159169', 'Testing')
        expect($stdout.string.split("\n").first).to eq 'Reply posted by @testcli to @joshfrench.'
      end
    end
    context "--location 'latitude,longitude'" do
      before do
        @cli.options = @cli.options.merge('location' => '41.03132,28.9869')
        stub_get('/1.1/statuses/show/263813522369159169.json').with(query: {include_my_retweet: 'false'}).to_return(body: fixture('status_with_mention.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_post('/1.1/statuses/update.json').with(body: {in_reply_to_status_id: '263813522369159169', status: '@joshfrench Testing', lat: '41.03132', long: '28.9869', trim_user: 'true'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.reply('263813522369159169', 'Testing')
        expect(a_get('/1.1/statuses/show/263813522369159169.json').with(query: {include_my_retweet: 'false'})).to have_been_made
        expect(a_post('/1.1/statuses/update.json').with(body: {in_reply_to_status_id: '263813522369159169', status: '@joshfrench Testing', lat: '41.03132', long: '28.9869', trim_user: 'true'})).to have_been_made
        expect(a_request(:get, 'http://checkip.dyndns.org/')).not_to have_been_made
        expect(a_request(:get, 'http://www.geoplugin.net/xml.gp?ip=50.131.22.169')).not_to have_been_made
      end
      it 'has the correct output' do
        @cli.reply('263813522369159169', 'Testing')
        expect($stdout.string.split("\n").first).to eq 'Reply posted by @testcli to @joshfrench.'
      end
    end
    context 'no status provided' do
      it 'opens an editor to prompt for the status' do
        expect(T::Editor).to receive(:gets).and_return 'Testing'
        @cli.reply('263813522369159169')
      end
    end
  end

  describe '#report_spam' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
      stub_post('/1.1/users/report_spam.json').with(body: {screen_name: 'sferik'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.report_spam('sferik')
      expect(a_post('/1.1/users/report_spam.json').with(body: {screen_name: 'sferik'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.report_spam('sferik')
      expect($stdout.string).to match(/^@testcli reported 1 user/)
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_post('/1.1/users/report_spam.json').with(body: {user_id: '7505382'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.report_spam('7505382')
        expect(a_post('/1.1/users/report_spam.json').with(body: {user_id: '7505382'})).to have_been_made
      end
    end
  end

  describe '#retweet' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
      stub_post('/1.1/statuses/retweet/26755176471724032.json').to_return(body: fixture('retweet.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.retweet('26755176471724032')
      expect(a_post('/1.1/statuses/retweet/26755176471724032.json')).to have_been_made
    end
    it 'has the correct output' do
      @cli.retweet('26755176471724032')
      expect($stdout.string).to match(/^@testcli retweeted 1 tweet.$/)
    end
  end

  describe '#retweets' do
    before do
      stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244102729860009983', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    context 'without arguments' do
      it 'requests the correct resource' do
        @cli.retweets
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244102729860009983', include_entities: 'false'})).to have_been_made.times(3)
      end
      it 'has the correct output' do
        @cli.retweets
        expect($stdout.string).to eq <<-EOS
   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

   @codeforamerica
   RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
   Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
   @TheaClay

   @fbjork
   RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
   http://t.co/kGEykswZ /cc @JRuby @headius

   @al3x
   RT @wcmaier: Better banking through better ops: build something new with us
   @Simplify (remote, PDX) http://t.co/8WgzKZH3

   @JEG2
   RT @tenderlove: If corporations are people, can we use them to drive in the
   carpool lane?

   @dhh
   RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest
   achievement: why this goulish jingoism is so warped http://t.co/kood278s

   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

   @codeforamerica
   RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
   Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
   @TheaClay

   @fbjork
   RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
   http://t.co/kGEykswZ /cc @JRuby @headius

   @al3x
   RT @wcmaier: Better banking through better ops: build something new with us
   @Simplify (remote, PDX) http://t.co/8WgzKZH3

   @JEG2
   RT @tenderlove: If corporations are people, can we use them to drive in the
   carpool lane?

   @dhh
   RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest
   achievement: why this goulish jingoism is so warped http://t.co/kood278s

   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

   @codeforamerica
   RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
   Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
   @TheaClay

   @fbjork
   RT @jondot: Just published: "Pragmatic Concurrency With #Ruby"
   http://t.co/kGEykswZ /cc @JRuby @headius

   @al3x
   RT @wcmaier: Better banking through better ops: build something new with us
   @Simplify (remote, PDX) http://t.co/8WgzKZH3

   @JEG2
   RT @tenderlove: If corporations are people, can we use them to drive in the
   carpool lane?

   @dhh
   RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest
   achievement: why this goulish jingoism is so warped http://t.co/kood278s

   @calebelston
   RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k

   @codeforamerica
   RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat,
   Sep 8 http://t.co/Sk5BM7U3 We'll see y'all there! #rhok @codeforamerica
   @TheaClay

        EOS
      end
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.retweets
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text
          244108728834592770,2012-09-07 16:23:50 +0000,calebelston,RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
          244107823733174272,2012-09-07 16:20:15 +0000,codeforamerica,"RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat, Sep 8 http://t.co/Sk5BM7U3  We'll see y'all there! #rhok @codeforamerica @TheaClay"
          244107236262170624,2012-09-07 16:17:55 +0000,fbjork,"RT @jondot: Just published: ""Pragmatic Concurrency With #Ruby"" http://t.co/kGEykswZ   /cc @JRuby @headius"
          244104558433951744,2012-09-07 16:07:16 +0000,al3x,"RT @wcmaier: Better banking through better ops: build something new with us @Simplify (remote, PDX) http://t.co/8WgzKZH3"
          244102834398851073,2012-09-07 16:00:25 +0000,JEG2,"RT @tenderlove: If corporations are people, can we use them to drive in the carpool lane?"
          244102729860009984,2012-09-07 16:00:00 +0000,dhh,RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest achievement: why this goulish jingoism is so warped http://t.co/kood278s
          244108728834592770,2012-09-07 16:23:50 +0000,calebelston,RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
          244107823733174272,2012-09-07 16:20:15 +0000,codeforamerica,"RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat, Sep 8 http://t.co/Sk5BM7U3  We'll see y'all there! #rhok @codeforamerica @TheaClay"
          244107236262170624,2012-09-07 16:17:55 +0000,fbjork,"RT @jondot: Just published: ""Pragmatic Concurrency With #Ruby"" http://t.co/kGEykswZ   /cc @JRuby @headius"
          244104558433951744,2012-09-07 16:07:16 +0000,al3x,"RT @wcmaier: Better banking through better ops: build something new with us @Simplify (remote, PDX) http://t.co/8WgzKZH3"
          244102834398851073,2012-09-07 16:00:25 +0000,JEG2,"RT @tenderlove: If corporations are people, can we use them to drive in the carpool lane?"
          244102729860009984,2012-09-07 16:00:00 +0000,dhh,RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest achievement: why this goulish jingoism is so warped http://t.co/kood278s
          244108728834592770,2012-09-07 16:23:50 +0000,calebelston,RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
          244107823733174272,2012-09-07 16:20:15 +0000,codeforamerica,"RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat, Sep 8 http://t.co/Sk5BM7U3  We'll see y'all there! #rhok @codeforamerica @TheaClay"
          244107236262170624,2012-09-07 16:17:55 +0000,fbjork,"RT @jondot: Just published: ""Pragmatic Concurrency With #Ruby"" http://t.co/kGEykswZ   /cc @JRuby @headius"
          244104558433951744,2012-09-07 16:07:16 +0000,al3x,"RT @wcmaier: Better banking through better ops: build something new with us @Simplify (remote, PDX) http://t.co/8WgzKZH3"
          244102834398851073,2012-09-07 16:00:25 +0000,JEG2,"RT @tenderlove: If corporations are people, can we use them to drive in the carpool lane?"
          244102729860009984,2012-09-07 16:00:00 +0000,dhh,RT @ggreenwald: Democrats parade Osama bin Laden's corpse as their proudest achievement: why this goulish jingoism is so warped http://t.co/kood278s
          244108728834592770,2012-09-07 16:23:50 +0000,calebelston,RT @olivercameron: Mosaic looks cool: http://t.co/A8013C9k
          244107823733174272,2012-09-07 16:20:15 +0000,codeforamerica,"RT @randomhacks: Going to Code Across Austin II: Y'all Come Hack Now, Sat, Sep 8 http://t.co/Sk5BM7U3  We'll see y'all there! #rhok @codeforamerica @TheaClay"
        EOS
      end
    end
    context '--decode-uris' do
      before do
        @cli.options = @cli.options.merge('decode_uris' => true)
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244102729860009983', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.retweets
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'true'})).to have_been_made
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244102729860009983', include_entities: 'true'})).to have_been_made.times(3)
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.retweets
        expect($stdout.string).to eq <<~EOS
          ID                  Posted at     Screen name      Text
          244108728834592770  Sep  7 08:23  @calebelston     RT @olivercameron: Mosaic ...
          244107823733174272  Sep  7 08:20  @codeforamerica  RT @randomhacks: Going to ...
          244107236262170624  Sep  7 08:17  @fbjork          RT @jondot: Just published...
          244104558433951744  Sep  7 08:07  @al3x            RT @wcmaier: Better bankin...
          244102834398851073  Sep  7 08:00  @JEG2            RT @tenderlove: If corpora...
          244102729860009984  Sep  7 08:00  @dhh             RT @ggreenwald: Democrats ...
          244108728834592770  Sep  7 08:23  @calebelston     RT @olivercameron: Mosaic ...
          244107823733174272  Sep  7 08:20  @codeforamerica  RT @randomhacks: Going to ...
          244107236262170624  Sep  7 08:17  @fbjork          RT @jondot: Just published...
          244104558433951744  Sep  7 08:07  @al3x            RT @wcmaier: Better bankin...
          244102834398851073  Sep  7 08:00  @JEG2            RT @tenderlove: If corpora...
          244102729860009984  Sep  7 08:00  @dhh             RT @ggreenwald: Democrats ...
          244108728834592770  Sep  7 08:23  @calebelston     RT @olivercameron: Mosaic ...
          244107823733174272  Sep  7 08:20  @codeforamerica  RT @randomhacks: Going to ...
          244107236262170624  Sep  7 08:17  @fbjork          RT @jondot: Just published...
          244104558433951744  Sep  7 08:07  @al3x            RT @wcmaier: Better bankin...
          244102834398851073  Sep  7 08:00  @JEG2            RT @tenderlove: If corpora...
          244102729860009984  Sep  7 08:00  @dhh             RT @ggreenwald: Democrats ...
          244108728834592770  Sep  7 08:23  @calebelston     RT @olivercameron: Mosaic ...
          244107823733174272  Sep  7 08:20  @codeforamerica  RT @randomhacks: Going to ...
        EOS
      end
      context '--reverse' do
        before do
          @cli.options = @cli.options.merge('reverse' => true)
        end
        it 'reverses the order of the sort' do
          @cli.retweets
          expect($stdout.string).to eq <<~EOS
            ID                  Posted at     Screen name      Text
            244107823733174272  Sep  7 08:20  @codeforamerica  RT @randomhacks: Going to ...
            244108728834592770  Sep  7 08:23  @calebelston     RT @olivercameron: Mosaic ...
            244102729860009984  Sep  7 08:00  @dhh             RT @ggreenwald: Democrats ...
            244102834398851073  Sep  7 08:00  @JEG2            RT @tenderlove: If corpora...
            244104558433951744  Sep  7 08:07  @al3x            RT @wcmaier: Better bankin...
            244107236262170624  Sep  7 08:17  @fbjork          RT @jondot: Just published...
            244107823733174272  Sep  7 08:20  @codeforamerica  RT @randomhacks: Going to ...
            244108728834592770  Sep  7 08:23  @calebelston     RT @olivercameron: Mosaic ...
            244102729860009984  Sep  7 08:00  @dhh             RT @ggreenwald: Democrats ...
            244102834398851073  Sep  7 08:00  @JEG2            RT @tenderlove: If corpora...
            244104558433951744  Sep  7 08:07  @al3x            RT @wcmaier: Better bankin...
            244107236262170624  Sep  7 08:17  @fbjork          RT @jondot: Just published...
            244107823733174272  Sep  7 08:20  @codeforamerica  RT @randomhacks: Going to ...
            244108728834592770  Sep  7 08:23  @calebelston     RT @olivercameron: Mosaic ...
            244102729860009984  Sep  7 08:00  @dhh             RT @ggreenwald: Democrats ...
            244102834398851073  Sep  7 08:00  @JEG2            RT @tenderlove: If corpora...
            244104558433951744  Sep  7 08:07  @al3x            RT @wcmaier: Better bankin...
            244107236262170624  Sep  7 08:17  @fbjork          RT @jondot: Just published...
            244107823733174272  Sep  7 08:20  @codeforamerica  RT @randomhacks: Going to ...
            244108728834592770  Sep  7 08:23  @calebelston     RT @olivercameron: Mosaic ...
          EOS
        end
      end
    end
    context '--number' do
      before do
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244107823733174271', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'limits the number of results to 1' do
        @cli.options = @cli.options.merge('number' => 1)
        @cli.retweets
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'false'})).to have_been_made
      end
      it 'limits the number of results to 201' do
        @cli.options = @cli.options.merge('number' => 201)
        @cli.retweets
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', max_id: '244107823733174271', include_entities: 'false'})).to have_been_made
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', screen_name: 'sferik', max_id: '244102729860009983', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.retweets('sferik')
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', screen_name: 'sferik', max_id: '244102729860009983', include_entities: 'false'})).to have_been_made.times(3)
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', user_id: '7505382', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', user_id: '7505382', max_id: '244102729860009983', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.retweets('7505382')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', user_id: '7505382', include_entities: 'false'})).to have_been_made
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', include_rts: 'true', user_id: '7505382', max_id: '244102729860009983', include_entities: 'false'})).to have_been_made.times(3)
        end
      end
    end
  end

  describe '#retweets_of_me' do
    before do
      stub_get('/1.1/statuses/retweets_of_me.json').with(query: {count: '20', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    context 'without arguments' do
      it 'requests the correct resource' do
        @cli.retweets_of_me
        expect(a_get('/1.1/statuses/retweets_of_me.json').with(query: {count: '20', include_entities: 'false'})).to have_been_made
      end
      it 'has the correct output' do
        @cli.retweets_of_me
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
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.retweets_of_me
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
        @cli.options = @cli.options.merge('decode_uris' => true)
        stub_get('/1.1/statuses/retweets_of_me.json').with(query: {count: '20', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.retweets_of_me
        expect(a_get('/1.1/statuses/retweets_of_me.json').with(query: {count: '20', include_entities: 'true'})).to have_been_made
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.retweets_of_me
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
          @cli.options = @cli.options.merge('reverse' => true)
        end
        it 'reverses the order of the sort' do
          @cli.retweets_of_me
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
        stub_get('/1.1/statuses/retweets_of_me.json').with(query: {count: '1', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/retweets_of_me.json').with(query: {count: '200', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        (1..181).step(20) do |count|
          stub_get('/1.1/statuses/retweets_of_me.json').with(query: {count: count, max_id: '244099460672679937', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
      end
      it 'limits the number of results to 1' do
        @cli.options = @cli.options.merge('number' => 1)
        @cli.retweets_of_me
        expect(a_get('/1.1/statuses/retweets_of_me.json').with(query: {count: '1', include_entities: 'false'})).to have_been_made
      end
      it 'limits the number of results to 201' do
        @cli.options = @cli.options.merge('number' => 201)
        @cli.retweets_of_me
        expect(a_get('/1.1/statuses/retweets_of_me.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made
        (1..181).step(20) do |count|
          expect(a_get('/1.1/statuses/retweets_of_me.json').with(query: {count: count, max_id: '244099460672679937', include_entities: 'false'})).to have_been_made
        end
      end
    end
  end

  describe '#ruler' do
    it 'has the correct output' do
      @cli.ruler
      expect($stdout.string.chomp.size).to eq 140
      expect($stdout.string.chomp).to eq '----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|'
    end
    context 'with indentation' do
      before do
        @cli.options = @cli.options.merge('indent' => 2)
      end
      it 'has the correct output' do
        @cli.ruler
        expect($stdout.string.chomp.size).to eq 142
        expect($stdout.string.chomp).to eq '  ----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|----|'
      end
    end
  end

  describe '#status' do
    before do
      stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resources' do
      @cli.status('55709764298092545')
      expect(a_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.status('55709764298092545')
      expect($stdout.string).to eq <<~EOS
        ID           55709764298092545
        Text         The problem with your code is that it's doing exactly what you told it to do.
        Screen name  @sferik
        Posted at    Apr  6  2011 (8 months ago)
        Retweets     320
        Favorites    50
        Source       Twitter for iPhone
        Location     Blowfish Sushi To Die For, 2170 Bryant St, San Francisco, California, United States
      EOS
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'has the correct output' do
        @cli.status('55709764298092545')
        expect($stdout.string).to eq <<~EOS
          ID,Posted at,Screen name,Text,Retweets,Favorites,Source,Location
          55709764298092545,2011-04-06 19:13:37 +0000,sferik,The problem with your code is that it's doing exactly what you told it to do.,320,50,Twitter for iPhone,"Blowfish Sushi To Die For, 2170 Bryant St, San Francisco, California, United States"
        EOS
      end
    end
    context 'with no street address' do
      before do
        stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status_no_street_address.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'has the correct output' do
        @cli.status('55709764298092545')
        expect($stdout.string).to eq <<~EOS
          ID           55709764298092550
          Text         The problem with your code is that it's doing exactly what you told it to do.
          Screen name  @sferik
          Posted at    Apr  6  2011 (8 months ago)
          Retweets     320
          Favorites    50
          Source       Twitter for iPhone
          Location     Blowfish Sushi To Die For, San Francisco, California, United States
        EOS
      end
    end
    context 'with no locality' do
      before do
        stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status_no_locality.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'has the correct output' do
        @cli.status('55709764298092545')
        expect($stdout.string).to eq <<~EOS
          ID           55709764298092549
          Text         The problem with your code is that it's doing exactly what you told it to do.
          Screen name  @sferik
          Posted at    Apr  6  2011 (8 months ago)
          Retweets     320
          Favorites    50
          Source       Twitter for iPhone
          Location     Blowfish Sushi To Die For, San Francisco, California, United States
        EOS
      end
    end
    context 'with no attributes' do
      before do
        stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status_no_attributes.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'has the correct output' do
        @cli.status('55709764298092545')
        expect($stdout.string).to eq <<~EOS
          ID           55709764298092546
          Text         The problem with your code is that it's doing exactly what you told it to do.
          Screen name  @sferik
          Posted at    Apr  6  2011 (8 months ago)
          Retweets     320
          Favorites    50
          Source       Twitter for iPhone
          Location     Blowfish Sushi To Die For, San Francisco, United States
        EOS
      end
    end
    context 'with no country' do
      before do
        stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status_no_country.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'has the correct output' do
        @cli.status('55709764298092545')
        expect($stdout.string).to eq <<~EOS
          ID           55709764298092547
          Text         The problem with your code is that it's doing exactly what you told it to do.
          Screen name  @sferik
          Posted at    Apr  6  2011 (8 months ago)
          Retweets     320
          Favorites    50
          Source       Twitter for iPhone
          Location     Blowfish Sushi To Die For, San Francisco
        EOS
      end
    end
    context 'with no full name' do
      before do
        stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status_no_full_name.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'has the correct output' do
        @cli.status('55709764298092545')
        expect($stdout.string).to eq <<~EOS
          ID           55709764298092548
          Text         The problem with your code is that it's doing exactly what you told it to do.
          Screen name  @sferik
          Posted at    Apr  6  2011 (8 months ago)
          Retweets     320
          Favorites    50
          Source       Twitter for iPhone
          Location     Blowfish Sushi To Die For
        EOS
      end
    end
    context 'with no place' do
      before do
        stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status_no_place.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_request(:get, 'https://maps.google.com/maps/api/geocode/json').with(query: {latlng: '37.75963095,-122.410067', sensor: 'false'}).to_return(body: fixture('geo.json'), headers: {content_type: 'application/json; charset=UTF-8'})
      end
      it 'has the correct output' do
        @cli.status('55709764298092545')
        expect($stdout.string).to eq <<~EOS
          ID           55709764298092551
          Text         The problem with your code is that it's doing exactly what you told it to do.
          Screen name  @sferik
          Posted at    Apr  6  2011 (8 months ago)
          Retweets     320
          Favorites    50
          Source       Twitter for iPhone
          Location     San Francisco, CA, United States
        EOS
      end
      context 'with no city' do
        before do
          stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status_no_place.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_request(:get, 'https://maps.google.com/maps/api/geocode/json').with(query: {latlng: '37.75963095,-122.410067', sensor: 'false'}).to_return(body: fixture('geo_no_city.json'), headers: {content_type: 'application/json; charset=UTF-8'})
        end
        it 'has the correct output' do
          @cli.status('55709764298092545')
          expect($stdout.string).to eq <<~EOS
            ID           55709764298092551
            Text         The problem with your code is that it's doing exactly what you told it to do.
            Screen name  @sferik
            Posted at    Apr  6  2011 (8 months ago)
            Retweets     320
            Favorites    50
            Source       Twitter for iPhone
            Location     CA, United States
          EOS
        end
      end
      context 'with no state' do
        before do
          stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status_no_place.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_request(:get, 'https://maps.google.com/maps/api/geocode/json').with(query: {latlng: '37.75963095,-122.410067', sensor: 'false'}).to_return(body: fixture('geo_no_state.json'), headers: {content_type: 'application/json; charset=UTF-8'})
        end
        it 'has the correct output' do
          @cli.status('55709764298092545')
          expect($stdout.string).to eq <<~EOS
            ID           55709764298092551
            Text         The problem with your code is that it's doing exactly what you told it to do.
            Screen name  @sferik
            Posted at    Apr  6  2011 (8 months ago)
            Retweets     320
            Favorites    50
            Source       Twitter for iPhone
            Location     United States
          EOS
        end
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.status('55709764298092545')
        expect($stdout.string).to eq <<~EOS
          ID                 Posted at     Screen name  Text                           ...
          55709764298092545  Apr  6  2011  @sferik      The problem with your code is t...
        EOS
      end
    end
    describe '--relative-dates' do
      before do
        stub_get('/1.1/statuses/show/55709764298092545.json').with(query: {include_my_retweet: 'false', include_entities: 'false'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/users/show.json').with(query: {screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
        @cli.options = @cli.options.merge('relative_dates' => true)
      end
      it 'status has the correct output (absolute and relative date together)' do
        @cli.status('55709764298092545')
        expect($stdout.string).to eq <<~EOS
          ID           55709764298092545
          Text         The problem with your code is that it's doing exactly what you told it to do.
          Screen name  @sferik
          Posted at    Apr  6  2011 (8 months ago)
          Retweets     320
          Favorites    50
          Source       Twitter for iPhone
          Location     Blowfish Sushi To Die For, 2170 Bryant St, San Francisco, California, United States
        EOS
      end
      it 'whois has the correct output (absolute and relative date together)' do
        @cli.whois('sferik')
        expect($stdout.string).to eq <<~EOS
          ID           7505382
          Since        Jul 16  2007 (4 years ago)
          Last update  @goldman You're near my home town! Say hi to Woodstock for me. (7 months ago)
          Screen name  @sferik
          Name         Erik Michaels-Ober
          Tweets       7,890
          Favorites    3,755
          Listed       118
          Following    212
          Followers    2,262
          Bio          Vagabond.
          Location     San Francisco
          URL          https://github.com/sferik
        EOS
      end
      context '--csv' do
        before do
          @cli.options = @cli.options.merge('csv' => true)
        end
        it 'has the correct output (absolute date in csv)' do
          @cli.status('55709764298092545')
          expect($stdout.string).to eq <<~EOS
            ID,Posted at,Screen name,Text,Retweets,Favorites,Source,Location
            55709764298092545,2011-04-06 19:13:37 +0000,sferik,The problem with your code is that it's doing exactly what you told it to do.,320,50,Twitter for iPhone,"Blowfish Sushi To Die For, 2170 Bryant St, San Francisco, California, United States"
          EOS
        end
      end
      context '--long' do
        before do
          @cli.options = @cli.options.merge('long' => true)
        end
        it 'outputs in long format' do
          @cli.status('55709764298092545')
          expect($stdout.string).to eq <<~EOS
            ID                 Posted at     Screen name  Text                           ...
            55709764298092545  8 months ago  @sferik      The problem with your code is t...
          EOS
        end
      end
    end
  end

  describe '#timeline' do
    before do
      stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    context 'without user' do
      it 'requests the correct resource' do
        @cli.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', include_entities: 'false'})).to have_been_made
      end
      it 'has the correct output' do
        @cli.timeline
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
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.timeline
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
        @cli.options = @cli.options.merge('decode_uris' => true)
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', include_entities: 'true'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', include_entities: 'true'})).to have_been_made
      end
      it 'decodes URLs' do
        @cli.timeline
        expect($stdout.string).to include 'https://twitter.com/sferik/status/243988000076337152'
      end
    end
    context '--exclude=replies' do
      before do
        @cli.options = @cli.options.merge('exclude' => 'replies')
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', exclude_replies: 'true', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'excludes replies' do
        @cli.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', exclude_replies: 'true', include_entities: 'false'})).to have_been_made
      end
    end
    context '--exclude=retweets' do
      before do
        @cli.options = @cli.options.merge('exclude' => 'retweets')
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', include_rts: 'false', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'excludes retweets' do
        @cli.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', include_rts: 'false', include_entities: 'false'})).to have_been_made
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.timeline
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
          @cli.options = @cli.options.merge('reverse' => true)
        end
        it 'reverses the order of the sort' do
          @cli.timeline
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
    context '--max-id' do
      before do
        @cli.options = @cli.options.merge('max_id' => 244_104_558_433_951_744)
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', max_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', max_id: '244104558433951744', include_entities: 'false'})).to have_been_made
      end
    end
    context '--number' do
      before do
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '1', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_entities: 'false'}).to_return(body: fixture('200_statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '1', max_id: '265500541700956160', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'limits the number of results to 1' do
        @cli.options = @cli.options.merge('number' => 1)
        @cli.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '1', include_entities: 'false'})).to have_been_made
      end
      it 'limits the number of results to 201' do
        @cli.options = @cli.options.merge('number' => 201)
        @cli.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '200', include_entities: 'false'})).to have_been_made
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '1', max_id: '265500541700956160', include_entities: 'false'})).to have_been_made
      end
    end
    context '--since-id' do
      before do
        @cli.options = @cli.options.merge('since_id' => 244_104_558_433_951_744)
        stub_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', since_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.timeline
        expect(a_get('/1.1/statuses/home_timeline.json').with(query: {count: '20', since_id: '244104558433951744', include_entities: 'false'})).to have_been_made
      end
    end
    context 'with a user passed' do
      before do
        stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '20', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.timeline('sferik')
        expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '20', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '20', user_id: '7505382', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.timeline('7505382')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '20', user_id: '7505382', include_entities: 'false'})).to have_been_made
        end
      end
      context '--max-id' do
        before do
          @cli.options = @cli.options.merge('max_id' => 244_104_558_433_951_744)
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '20', screen_name: 'sferik', max_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.timeline('sferik')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '20', screen_name: 'sferik', max_id: '244104558433951744', include_entities: 'false'})).to have_been_made
        end
      end
      context '--number' do
        before do
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '1', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('200_statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '1', screen_name: 'sferik', max_id: '265500541700956160', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'limits the number of results to 1' do
          @cli.options = @cli.options.merge('number' => 1)
          @cli.timeline('sferik')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '1', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
        end
        it 'limits the number of results to 201' do
          @cli.options = @cli.options.merge('number' => 201)
          @cli.timeline('sferik')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '200', screen_name: 'sferik', include_entities: 'false'})).to have_been_made
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '1', screen_name: 'sferik', max_id: '265500541700956160', include_entities: 'false'})).to have_been_made
        end
      end
      context '--since-id' do
        before do
          @cli.options = @cli.options.merge('since_id' => 244_104_558_433_951_744)
          stub_get('/1.1/statuses/user_timeline.json').with(query: {count: '20', screen_name: 'sferik', since_id: '244104558433951744', include_entities: 'false'}).to_return(body: fixture('statuses.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.timeline('sferik')
          expect(a_get('/1.1/statuses/user_timeline.json').with(query: {count: '20', screen_name: 'sferik', since_id: '244104558433951744', include_entities: 'false'})).to have_been_made
        end
      end
    end
  end

  describe '#trends' do
    before do
      stub_get('/1.1/trends/place.json').with(query: {id: '1'}).to_return(body: fixture('trends.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.trends
      expect(a_get('/1.1/trends/place.json').with(query: {id: '1'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.trends
      expect($stdout.string.chomp).to eq '#sevenwordsaftersex  Walkman              Allen Iverson'
    end
    context '--exclude-hashtags' do
      before do
        @cli.options = @cli.options.merge('exclude-hashtags' => true)
        stub_get('/1.1/trends/place.json').with(query: {id: '1', exclude: 'hashtags'}).to_return(body: fixture('trends.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.trends
        expect(a_get('/1.1/trends/place.json').with(query: {id: '1', exclude: 'hashtags'})).to have_been_made
      end
      it 'has the correct output' do
        @cli.trends
        expect($stdout.string.chomp).to eq '#sevenwordsaftersex  Walkman              Allen Iverson'
      end
    end
    context 'with a WOEID passed' do
      before do
        stub_get('/1.1/trends/place.json').with(query: {id: '2487956'}).to_return(body: fixture('trends.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.trends('2487956')
        expect(a_get('/1.1/trends/place.json').with(query: {id: '2487956'})).to have_been_made
      end
      it 'has the correct output' do
        @cli.trends('2487956')
        expect($stdout.string.chomp).to eq '#sevenwordsaftersex  Walkman              Allen Iverson'
      end
    end
  end

  describe '#trend_locations' do
    before do
      stub_get('/1.1/trends/available.json').to_return(body: fixture('locations.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.trend_locations
      expect(a_get('/1.1/trends/available.json')).to have_been_made
    end
    it 'has the correct output' do
      @cli.trend_locations
      expect($stdout.string.chomp).to eq 'San Francisco  Soweto         United States  Worldwide'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.trend_locations
        expect($stdout.string.chomp).to eq <<~EOS.chomp
          WOEID,Parent ID,Type,Name,Country
          2487956,23424977,Town,San Francisco,United States
          1587677,23424942,Unknown,Soweto,South Africa
          23424977,1,Country,United States,United States
          1,0,Supername,Worldwide,
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.trend_locations
        expect($stdout.string.chomp).to eq <<~EOS.chomp
          WOEID     Parent ID  Type       Name           Country
           2487956   23424977  Town       San Francisco  United States
           1587677   23424942  Unknown    Soweto         South Africa
          23424977          1  Country    United States  United States
                 1          0  Supername  Worldwide      
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.trend_locations
        expect($stdout.string.chomp).to eq 'Worldwide      United States  Soweto         San Francisco'
      end
    end
    context '--sort=country' do
      before do
        @cli.options = @cli.options.merge('sort' => 'country')
      end
      it 'sorts by the country name' do
        @cli.trend_locations
        expect($stdout.string.chomp).to eq 'Worldwide      Soweto         San Francisco  United States'
      end
    end
    context '--sort=parent' do
      before do
        @cli.options = @cli.options.merge('sort' => 'parent')
      end
      it 'sorts by the parent ID' do
        @cli.trend_locations
        expect($stdout.string.chomp).to eq 'Worldwide      United States  Soweto         San Francisco'
      end
    end
    context '--sort=type' do
      before do
        @cli.options = @cli.options.merge('sort' => 'type')
      end
      it 'sorts by the type' do
        @cli.trend_locations
        expect($stdout.string.chomp).to eq 'United States  Worldwide      San Francisco  Soweto'
      end
    end
    context '--sort=woeid' do
      before do
        @cli.options = @cli.options.merge('sort' => 'woeid')
      end
      it 'sorts by the WOEID' do
        @cli.trend_locations
        expect($stdout.string.chomp).to eq 'Worldwide      Soweto         San Francisco  United States'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.trend_locations
        expect($stdout.string.chomp).to eq 'Worldwide      San Francisco  United States  Soweto'
      end
    end
  end

  describe '#unfollow' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
    end
    context 'one user' do
      it 'requests the correct resource' do
        stub_post('/1.1/friendships/destroy.json').with(body: {screen_name: 'sferik'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
        @cli.unfollow('sferik')
        expect(a_post('/1.1/friendships/destroy.json').with(body: {screen_name: 'sferik'})).to have_been_made
      end
      it 'has the correct output' do
        stub_post('/1.1/friendships/destroy.json').with(body: {screen_name: 'sferik'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
        @cli.unfollow('sferik')
        expect($stdout.string).to match(/^@testcli is no longer following 1 user\.$/)
      end
      context '--id' do
        before do
          @cli.options = @cli.options.merge('id' => true)
          stub_post('/1.1/friendships/destroy.json').with(body: {user_id: '7505382'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
        end
        it 'requests the correct resource' do
          @cli.unfollow('7505382')
          expect(a_post('/1.1/friendships/destroy.json').with(body: {user_id: '7505382'})).to have_been_made
        end
      end
      context 'Twitter is down' do
        it 'retries 3 times and then raise an error' do
          stub_post('/1.1/friendships/destroy.json').with(body: {screen_name: 'sferik'}).to_return(status: 502, headers: {content_type: 'application/json; charset=utf-8'})
          expect do
            @cli.unfollow('sferik')
          end.to raise_error(Twitter::Error::BadGateway)
          expect(a_post('/1.1/friendships/destroy.json').with(body: {screen_name: 'sferik'})).to have_been_made.times(3)
        end
      end
    end
  end

  describe '#update' do
    before do
      @cli.options = @cli.options.merge('profile' => fixture_path + '/.trc')
      stub_post('/1.1/statuses/update.json').with(body: {status: 'Testing', trim_user: 'true'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_request(:get, 'http://checkip.dyndns.org/').to_return(body: fixture('checkip.html'), headers: {content_type: 'text/html'})
      stub_request(:get, 'http://www.geoplugin.net/xml.gp?ip=50.131.22.169').to_return(body: fixture('geoplugin.xml'), headers: {content_type: 'application/xml'})
    end
    it 'requests the correct resource' do
      @cli.update('Testing')
      expect(a_post('/1.1/statuses/update.json').with(body: {status: 'Testing', trim_user: 'true'})).to have_been_made
      expect(a_request(:get, 'http://checkip.dyndns.org/')).not_to have_been_made
      expect(a_request(:get, 'http://www.geoplugin.net/xml.gp?ip=50.131.22.169')).not_to have_been_made
    end
    it 'has the correct output' do
      @cli.update('Testing')
      expect($stdout.string.split("\n").first).to eq 'Tweet posted by @testcli.'
    end
    context 'with file' do
      before do
        @cli.options = @cli.options.merge('file' => fixture_path + '/long.png')
        stub_request(:post, 'https://upload.twitter.com/1.1/media/upload.json').to_return(body: fixture('upload.json'), headers: {content_type: 'application/json; charset=utf-8'})
        stub_post('/1.1/statuses/update.json').to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.update('Testing')
        expect(a_request(:post, 'https://upload.twitter.com/1.1/media/upload.json')).to have_been_made
        expect(a_post('/1.1/statuses/update.json')).to have_been_made
      end
      it 'has the correct output' do
        @cli.update('Testing')
        expect($stdout.string.split("\n").first).to eq 'Tweet posted by @testcli.'
      end
    end
    context '--location' do
      before do
        @cli.options = @cli.options.merge('location' => 'location')
        stub_post('/1.1/statuses/update.json').with(body: {status: 'Testing', lat: '37.76969909668', long: '-122.39330291748', trim_user: 'true'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.update('Testing')
        expect(a_post('/1.1/statuses/update.json').with(body: {status: 'Testing', lat: '37.76969909668', long: '-122.39330291748', trim_user: 'true'})).to have_been_made
        expect(a_request(:get, 'http://checkip.dyndns.org/')).to have_been_made
        expect(a_request(:get, 'http://www.geoplugin.net/xml.gp?ip=50.131.22.169')).to have_been_made
      end
      it 'has the correct output' do
        @cli.update('Testing')
        expect($stdout.string.split("\n").first).to eq 'Tweet posted by @testcli.'
      end
    end
    context "--location 'latitude,longitude'" do
      before do
        @cli.options = @cli.options.merge('location' => '41.03132,28.9869')
        stub_post('/1.1/statuses/update.json').with(body: {status: 'Testing', lat: '41.03132', long: '28.9869', trim_user: 'true'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.update('Testing')
        expect(a_post('/1.1/statuses/update.json').with(body: {status: 'Testing', lat: '41.03132', long: '28.9869', trim_user: 'true'})).to have_been_made
        expect(a_request(:get, 'http://checkip.dyndns.org/')).not_to have_been_made
        expect(a_request(:get, 'http://www.geoplugin.net/xml.gp?ip=50.131.22.169')).not_to have_been_made
      end
      it 'has the correct output' do
        @cli.update('Testing')
        expect($stdout.string.split("\n").first).to eq 'Tweet posted by @testcli.'
      end
    end
    context 'no status provided' do
      it 'opens an editor to prompt for the status' do
        expect(T::Editor).to receive(:gets).and_return 'Testing'
        @cli.update
      end
    end
  end

  describe '#users' do
    before do
      stub_get('/1.1/users/lookup.json').with(query: {screen_name: 'sferik,pengwynn'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.users('sferik', 'pengwynn')
      expect(a_get('/1.1/users/lookup.json').with(query: {screen_name: 'sferik,pengwynn'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.users('sferik', 'pengwynn')
      expect($stdout.string.chomp).to eq 'pengwynn  sferik'
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'outputs in CSV format' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          14100886,2008-03-08 16:34:22 +0000,2012-07-07 20:33:19 +0000,6940,192,358,3427,5457,pengwynn,Wynn Netherland,false,false,"Christian, husband, father, GitHubber, Co-host of @thechangelog, Co-author of Sass, Compass, #CSS book  http://wynn.fm/sass-meap",@akosmasoftware Sass book! @hcatlin @nex3 are the brains behind Sass. :-),"Denton, TX",http://wynnnetherland.com
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string).to eq <<~EOS
          ID        Since         Last tweeted at  Tweets  Favorites  Listed  Following...
          14100886  Mar  8  2008  Jul  7 12:33       6940        192     358       3427...
           7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212...
        EOS
      end
    end
    context '--reverse' do
      before do
        @cli.options = @cli.options.merge('reverse' => true)
      end
      it 'reverses the order of the sort' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=favorites' do
      before do
        @cli.options = @cli.options.merge('sort' => 'favorites')
      end
      it 'sorts by the number of favorites' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=followers' do
      before do
        @cli.options = @cli.options.merge('sort' => 'followers')
      end
      it 'sorts by the number of followers' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=friends' do
      before do
        @cli.options = @cli.options.merge('sort' => 'friends')
      end
      it 'sorts by the number of friends' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_get('/1.1/users/lookup.json').with(query: {user_id: '7505382,14100886'}).to_return(body: fixture('users.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.users('7505382', '14100886')
        expect(a_get('/1.1/users/lookup.json').with(query: {user_id: '7505382,14100886'})).to have_been_made
      end
    end
    context '--sort=listed' do
      before do
        @cli.options = @cli.options.merge('sort' => 'listed')
      end
      it 'sorts by the number of list memberships' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=since' do
      before do
        @cli.options = @cli.options.merge('sort' => 'since')
      end
      it 'sorts by the time when Twitter acount was created' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string.chomp).to eq 'sferik    pengwynn'
      end
    end
    context '--sort=tweets' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweets')
      end
      it 'sorts by the number of Tweets' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--sort=tweeted' do
      before do
        @cli.options = @cli.options.merge('sort' => 'tweeted')
      end
      it 'sorts by the time of the last Tweet' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
    context '--unsorted' do
      before do
        @cli.options = @cli.options.merge('unsorted' => true)
      end
      it 'is not sorted' do
        @cli.users('sferik', 'pengwynn')
        expect($stdout.string.chomp).to eq 'pengwynn  sferik'
      end
    end
  end

  describe '#version' do
    it 'has the correct output' do
      @cli.version
      expect($stdout.string.chomp).to eq T::Version.to_s
    end
  end

  describe '#whois' do
    before do
      stub_get('/1.1/users/show.json').with(query: {screen_name: 'sferik', include_entities: 'false'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.whois('sferik')
      expect(a_get('/1.1/users/show.json').with(query: {screen_name: 'sferik', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.whois('sferik')
      expect($stdout.string).to eq <<~EOS
        ID           7505382
        Since        Jul 16  2007 (4 years ago)
        Last update  @goldman You're near my home town! Say hi to Woodstock for me. (7 months ago)
        Screen name  @sferik
        Name         Erik Michaels-Ober
        Tweets       7,890
        Favorites    3,755
        Listed       118
        Following    212
        Followers    2,262
        Bio          Vagabond.
        Location     San Francisco
        URL          https://github.com/sferik
      EOS
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'has the correct output' do
        @cli.whois('sferik')
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--id' do
      before do
        @cli.options = @cli.options.merge('id' => true)
        stub_get('/1.1/users/show.json').with(query: {user_id: '7505382', include_entities: 'false'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end
      it 'requests the correct resource' do
        @cli.whois('7505382')
        expect(a_get('/1.1/users/show.json').with(query: {user_id: '7505382', include_entities: 'false'})).to have_been_made
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.whois('sferik')
        expect($stdout.string).to eq <<~EOS
          ID       Since         Last tweeted at  Tweets  Favorites  Listed  Following ...
          7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212 ...
        EOS
      end
    end
  end

  describe '#whoami' do
    before do
      stub_get('/1.1/users/show.json').with(query: {screen_name: 'testcli', include_entities: 'false'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end
    it 'requests the correct resource' do
      @cli.whoami
      expect(a_get('/1.1/users/show.json').with(query: {screen_name: 'testcli', include_entities: 'false'})).to have_been_made
    end
    it 'has the correct output' do
      @cli.whoami
      expect($stdout.string).to eq <<~EOS
        ID           7505382
        Since        Jul 16  2007 (4 years ago)
        Last update  @goldman You're near my home town! Say hi to Woodstock for me. (7 months ago)
        Screen name  @sferik
        Name         Erik Michaels-Ober
        Tweets       7,890
        Favorites    3,755
        Listed       118
        Following    212
        Followers    2,262
        Bio          Vagabond.
        Location     San Francisco
        URL          https://github.com/sferik
      EOS
    end
    context '--csv' do
      before do
        @cli.options = @cli.options.merge('csv' => true)
      end
      it 'has the correct output' do
        @cli.whoami
        expect($stdout.string).to eq <<~EOS
          ID,Since,Last tweeted at,Tweets,Favorites,Listed,Following,Followers,Screen name,Name,Verified,Protected,Bio,Status,Location,URL
          7505382,2007-07-16 12:59:01 +0000,2012-07-08 18:29:20 +0000,7890,3755,118,212,2262,sferik,Erik Michaels-Ober,false,false,Vagabond.,@goldman You're near my home town! Say hi to Woodstock for me.,San Francisco,https://github.com/sferik
        EOS
      end
    end
    context '--long' do
      before do
        @cli.options = @cli.options.merge('long' => true)
      end
      it 'outputs in long format' do
        @cli.whoami
        expect($stdout.string).to eq <<~EOS
          ID       Since         Last tweeted at  Tweets  Favorites  Listed  Following ...
          7505382  Jul 16  2007  Jul  8 10:29       7890       3755     118        212 ...
        EOS
      end
    end
    context 'no configuration' do
      it 'prints a helpful message and no errors' do
        T::RCFile.instance.path = ''
        @cli = T::CLI.new
        @cli.whoami
        expect($stderr.string).to eq "You haven't authorized an account, run `t authorize` to get started.\n"
      end
    end
  end
end
