# encoding: utf-8

require 'helper'

describe T::Delete do
  before do
    T::RCFile.instance.path = "#{fixture_path}/.trc"
    @delete = described_class.new
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

  describe '#block' do
    before do
      @delete.options = @delete.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/blocks/destroy.json').with(body: {screen_name: 'sferik'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      @delete.block('sferik')
      expect(a_post('/1.1/blocks/destroy.json').with(body: {screen_name: 'sferik'})).to have_been_made
    end

    it 'has the correct output' do
      @delete.block('sferik')
      expect($stdout.string).to match(/^@testcli unblocked 1 user\.$/)
    end

    context '--id' do
      before do
        @delete.options = @delete.options.merge('id' => true)
        stub_post('/1.1/blocks/destroy.json').with(body: {user_id: '7505382'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end

      it 'requests the correct resource' do
        @delete.block('7505382')
        expect(a_post('/1.1/blocks/destroy.json').with(body: {user_id: '7505382'})).to have_been_made
      end
    end
  end

  describe '#dm' do
    before do
      @delete.options = @delete.options.merge('profile' => "#{fixture_path}/.trc")
      stub_get('/1.1/direct_messages/events/show.json').with(query: {id: '1773478249'}).to_return(body: fixture('direct_message_event.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_delete('/1.1/direct_messages/events/destroy.json').with(query: {id: '1773478249'}).to_return(body: fixture('direct_message_event.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/users/show.json').with(query: {user_id: '58983'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      expect(Readline).to receive(:readline).with('Are you sure you want to permanently delete the direct message to @sferik: "testing"? [y/N] ', false).and_return('yes')
      @delete.dm('1773478249')
      expect(a_get('/1.1/direct_messages/events/show.json').with(query: {id: '1773478249'})).to have_been_made
      expect(a_delete('/1.1/direct_messages/events/destroy.json').with(query: {id: '1773478249'})).to have_been_made
      expect(a_get('/1.1/users/show.json').with(query: {user_id: '58983'})).to have_been_made
    end

    context 'yes' do
      it 'has the correct output' do
        expect(Readline).to receive(:readline).with('Are you sure you want to permanently delete the direct message to @sferik: "testing"? [y/N] ', false).and_return('yes')
        @delete.dm('1773478249')
        expect($stdout.string.chomp).to eq '@testcli deleted the direct message sent to @sferik: "testing"'
      end
    end

    context 'no' do
      it 'has the correct output' do
        expect(Readline).to receive(:readline).with('Are you sure you want to permanently delete the direct message to @sferik: "testing"? [y/N] ', false).and_return('no')
        @delete.dm('1773478249')
        expect($stdout.string.chomp).to be_empty
      end
    end

    context '--force' do
      before do
        @delete.options = @delete.options.merge('force' => true)
      end

      it 'requests the correct resource' do
        @delete.dm('1773478249')
        expect(a_delete('/1.1/direct_messages/events/destroy.json').with(query: {id: '1773478249'})).to have_been_made
      end

      it 'has the correct output' do
        @delete.dm('1773478249')
        expect($stdout.string.chomp).to eq '@testcli deleted 1 direct message.'
      end
    end
  end

  describe '#favorite' do
    before do
      @delete.options = @delete.options.merge('profile' => "#{fixture_path}/.trc")
      stub_get('/1.1/statuses/show/28439861609.json').with(query: {include_my_retweet: 'false'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_post('/1.1/favorites/destroy.json').with(body: {id: '28439861609'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      expect(Readline).to receive(:readline).with("Are you sure you want to remove @sferik's status: \"The problem with your code is that it's doing exactly what you told it to do.\" from your favorites? [y/N] ", false).and_return('yes')
      @delete.favorite('28439861609')
      expect(a_get('/1.1/statuses/show/28439861609.json').with(query: {include_my_retweet: 'false'})).to have_been_made
      expect(a_post('/1.1/favorites/destroy.json').with(body: {id: '28439861609'})).to have_been_made
    end

    context 'yes' do
      it 'has the correct output' do
        expect(Readline).to receive(:readline).with("Are you sure you want to remove @sferik's status: \"The problem with your code is that it's doing exactly what you told it to do.\" from your favorites? [y/N] ", false).and_return('yes')
        @delete.favorite('28439861609')
        expect($stdout.string).to match(/^@testcli unfavorited @sferik's status: "The problem with your code is that it's doing exactly what you told it to do\."$/)
      end
    end

    context 'no' do
      it 'has the correct output' do
        expect(Readline).to receive(:readline).with("Are you sure you want to remove @sferik's status: \"The problem with your code is that it's doing exactly what you told it to do.\" from your favorites? [y/N] ", false).and_return('no')
        @delete.favorite('28439861609')
        expect($stdout.string.chomp).to be_empty
      end
    end

    context '--force' do
      before do
        @delete.options = @delete.options.merge('force' => true)
      end

      it 'requests the correct resource' do
        @delete.favorite('28439861609')
        expect(a_post('/1.1/favorites/destroy.json').with(body: {id: '28439861609'})).to have_been_made
      end

      it 'has the correct output' do
        @delete.favorite('28439861609')
        expect($stdout.string).to match(/^@testcli unfavorited @sferik's status: "The problem with your code is that it's doing exactly what you told it to do\."$/)
      end
    end
  end

  describe '#list' do
    before do
      @delete.options = @delete.options.merge('profile' => "#{fixture_path}/.trc")
      stub_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_get('/1.1/lists/show.json').with(query: {owner_id: '7505382', slug: 'presidents'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_post('/1.1/lists/destroy.json').with(body: {owner_id: '7505382', list_id: '8863586'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      expect(Readline).to receive(:readline).with('Are you sure you want to permanently delete the list "presidents"? [y/N] ', false).and_return('yes')
      @delete.list('presidents')
      expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
      expect(a_post('/1.1/lists/destroy.json').with(body: {owner_id: '7505382', list_id: '8863586'})).to have_been_made
    end

    context 'yes' do
      it 'has the correct output' do
        expect(Readline).to receive(:readline).with('Are you sure you want to permanently delete the list "presidents"? [y/N] ', false).and_return('yes')
        @delete.list('presidents')
        expect($stdout.string.chomp).to eq '@testcli deleted the list "presidents".'
      end
    end

    context 'no' do
      it 'has the correct output' do
        expect(Readline).to receive(:readline).with('Are you sure you want to permanently delete the list "presidents"? [y/N] ', false).and_return('no')
        @delete.list('presidents')
        expect($stdout.string.chomp).to be_empty
      end
    end

    context '--force' do
      before do
        @delete.options = @delete.options.merge('force' => true)
      end

      it 'requests the correct resource' do
        @delete.list('presidents')
        expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
        expect(a_post('/1.1/lists/destroy.json').with(body: {owner_id: '7505382', list_id: '8863586'})).to have_been_made
      end

      it 'has the correct output' do
        @delete.list('presidents')
        expect($stdout.string.chomp).to eq '@testcli deleted the list "presidents".'
      end
    end

    context '--id' do
      before do
        @delete.options = @delete.options.merge('id' => true)
        stub_get('/1.1/lists/show.json').with(query: {owner_id: '7505382', list_id: '8863586'}).to_return(body: fixture('list.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end

      it 'requests the correct resource' do
        expect(Readline).to receive(:readline).with('Are you sure you want to permanently delete the list "presidents"? [y/N] ', false).and_return('yes')
        @delete.list('8863586')
        expect(a_get('/1.1/lists/show.json').with(query: {owner_id: '7505382', list_id: '8863586'})).to have_been_made
        expect(a_get('/1.1/account/verify_credentials.json').with(query: {skip_status: 'true'})).to have_been_made
        expect(a_post('/1.1/lists/destroy.json').with(body: {owner_id: '7505382', list_id: '8863586'})).to have_been_made
      end
    end
  end

  describe '#mute' do
    before do
      @delete.options = @delete.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/mutes/users/destroy.json').with(body: {screen_name: 'sferik'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      @delete.mute('sferik')
      expect(a_post('/1.1/mutes/users/destroy.json').with(body: {screen_name: 'sferik'})).to have_been_made
    end

    it 'has the correct output' do
      @delete.mute('sferik')
      expect($stdout.string).to match(/^@testcli unmuted 1 user\.$/)
    end

    context '--id' do
      before do
        @delete.options = @delete.options.merge('id' => true)
        stub_post('/1.1/mutes/users/destroy.json').with(body: {user_id: '7505382'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
      end

      it 'requests the correct resource' do
        @delete.mute('7505382')
        expect(a_post('/1.1/mutes/users/destroy.json').with(body: {user_id: '7505382'})).to have_been_made
      end
    end
  end

  describe '#account' do
    before do
      @delete.options = @delete.options.merge('profile' => "#{fixture_path}/.trc")
      delete_cli = {
        'delete_cli' => {
          'dw123' => {
            'consumer_key' => 'abc123',
            'secret' => 'epzrjvxtumoc',
            'token' => '428004849-cebdct6bwobn',
            'username' => 'deletecli',
            'consumer_secret' => 'asdfasd223sd2',
          },
          'dw1234' => {
            'consumer_key' => 'abc1234',
            'secret' => 'epzrjvxtumoc',
            'token' => '428004849-cebdct6bwobn',
            'username' => 'deletecli',
            'consumer_secret' => 'asdfasd223sd2',
          },
        },
      }
      rcfile = @delete.instance_variable_get(:@rcfile)
      rcfile.profiles.merge!(delete_cli)
      rcfile.send(:write)
    end

    after do
      rcfile = @delete.instance_variable_get(:@rcfile)
      rcfile.delete_profile('delete_cli')
    end

    it 'deletes the key' do
      @delete.account('delete_cli', 'dw1234')
      rcfile = @delete.instance_variable_get(:@rcfile)
      expect(rcfile.profiles['delete_cli'].keys.include?('dw1234')).to be false
    end

    it 'deletes the account' do
      @delete.account('delete_cli')
      rcfile = @delete.instance_variable_get(:@rcfile)
      expect(rcfile.profiles.keys.include?('delete_cli')).to be false
    end
  end

  describe '#status' do
    before do
      @delete.options = @delete.options.merge('profile' => "#{fixture_path}/.trc")
      stub_get('/1.1/statuses/show/26755176471724032.json').with(query: {include_my_retweet: 'false'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
      stub_post('/1.1/statuses/destroy/26755176471724032.json').with(body: {trim_user: 'true'}).to_return(body: fixture('status.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      expect(Readline).to receive(:readline).with("Are you sure you want to permanently delete @sferik's status: \"The problem with your code is that it's doing exactly what you told it to do.\"? [y/N] ", false).and_return('yes')
      @delete.status('26755176471724032')
      expect(a_get('/1.1/statuses/show/26755176471724032.json').with(query: {include_my_retweet: 'false'})).to have_been_made
      expect(a_post('/1.1/statuses/destroy/26755176471724032.json').with(body: {trim_user: 'true'})).to have_been_made
    end

    context 'yes' do
      it 'has the correct output' do
        expect(Readline).to receive(:readline).with("Are you sure you want to permanently delete @sferik's status: \"The problem with your code is that it's doing exactly what you told it to do.\"? [y/N] ", false).and_return('yes')
        @delete.status('26755176471724032')
        expect($stdout.string.chomp).to eq "@testcli deleted the Tweet: \"The problem with your code is that it's doing exactly what you told it to do.\""
      end
    end

    context 'no' do
      it 'has the correct output' do
        expect(Readline).to receive(:readline).with("Are you sure you want to permanently delete @sferik's status: \"The problem with your code is that it's doing exactly what you told it to do.\"? [y/N] ", false).and_return('no')
        @delete.status('26755176471724032')
        expect($stdout.string.chomp).to be_empty
      end
    end

    context '--force' do
      before do
        @delete.options = @delete.options.merge('force' => true)
      end

      it 'requests the correct resource' do
        @delete.status('26755176471724032')
        expect(a_post('/1.1/statuses/destroy/26755176471724032.json').with(body: {trim_user: 'true'})).to have_been_made
      end

      it 'has the correct output' do
        @delete.status('26755176471724032')
        expect($stdout.string.chomp).to eq "@testcli deleted the Tweet: \"The problem with your code is that it's doing exactly what you told it to do.\""
      end
    end
  end
end
