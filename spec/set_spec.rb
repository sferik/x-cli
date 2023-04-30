# encoding: utf-8

require 'helper'

describe T::Set do
  before do
    T::RCFile.instance.path = "#{fixture_path}/.trc"
    @set = described_class.new
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

  describe '#active' do
    before do
      @set.options = @set.options.merge('profile' => "#{fixture_path}/.trc_set")
    end

    it 'has the correct output' do
      @set.active('testcli', 'abc123')
      expect($stdout.string.chomp).to eq 'Active account has been updated to testcli.'
    end

    it 'accepts an account name without a consumer key' do
      @set.active('testcli')
      expect($stdout.string.chomp).to eq 'Active account has been updated to testcli.'
    end

    it 'is case insensitive' do
      @set.active('TestCLI', 'abc123')
      expect($stdout.string.chomp).to eq 'Active account has been updated to testcli.'
    end

    it 'raises an error if username is ambiguous' do
      expect do
        @set.active('test', 'abc123')
      end.to raise_error(ArgumentError, /Username test is ambiguous/)
    end

    it 'raises an error if the username is not found' do
      expect do
        @set.active('clitest')
      end.to raise_error(ArgumentError, /Username clitest is not found/)
    end
  end

  describe '#bio' do
    before do
      @set.options = @set.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/account/update_profile.json').with(body: {description: 'Vagabond.'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      @set.bio('Vagabond.')
      expect(a_post('/1.1/account/update_profile.json').with(body: {description: 'Vagabond.'})).to have_been_made
    end

    it 'has the correct output' do
      @set.bio('Vagabond.')
      expect($stdout.string.chomp).to eq "@testcli's bio has been updated."
    end
  end

  describe '#language' do
    before do
      @set.options = @set.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/account/settings.json').with(body: {lang: 'en'}).to_return(body: fixture('settings.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      @set.language('en')
      expect(a_post('/1.1/account/settings.json').with(body: {lang: 'en'})).to have_been_made
    end

    it 'has the correct output' do
      @set.language('en')
      expect($stdout.string.chomp).to eq "@testcli's language has been updated."
    end
  end

  describe '#location' do
    before do
      @set.options = @set.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/account/update_profile.json').with(body: {location: 'San Francisco'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      @set.location('San Francisco')
      expect(a_post('/1.1/account/update_profile.json').with(body: {location: 'San Francisco'})).to have_been_made
    end

    it 'has the correct output' do
      @set.location('San Francisco')
      expect($stdout.string.chomp).to eq "@testcli's location has been updated."
    end
  end

  describe '#name' do
    before do
      @set.options = @set.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/account/update_profile.json').with(body: {name: 'Erik Michaels-Ober'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      @set.name('Erik Michaels-Ober')
      expect(a_post('/1.1/account/update_profile.json').with(body: {name: 'Erik Michaels-Ober'})).to have_been_made
    end

    it 'has the correct output' do
      @set.name('Erik Michaels-Ober')
      expect($stdout.string.chomp).to eq "@testcli's name has been updated."
    end
  end

  describe '#profile_background_image' do
    before do
      @set.options = @set.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/account/update_profile_background_image.json').to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      @set.profile_background_image("#{fixture_path}/we_concept_bg2.png")
      expect(a_post('/1.1/account/update_profile_background_image.json')).to have_been_made
    end

    it 'has the correct output' do
      @set.profile_background_image("#{fixture_path}/we_concept_bg2.png")
      expect($stdout.string.chomp).to eq "@testcli's background image has been updated."
    end
  end

  describe '#profile_image' do
    before do
      @set.options = @set.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/account/update_profile_image.json').to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      @set.profile_image("#{fixture_path}/me.jpg")
      expect(a_post('/1.1/account/update_profile_image.json')).to have_been_made
    end

    it 'has the correct output' do
      @set.profile_image("#{fixture_path}/me.jpg")
      expect($stdout.string.chomp).to eq "@testcli's image has been updated."
    end
  end

  describe '#website' do
    before do
      @set.options = @set.options.merge('profile' => "#{fixture_path}/.trc")
      stub_post('/1.1/account/update_profile.json').with(body: {url: 'https://github.com/sferik'}).to_return(body: fixture('sferik.json'), headers: {content_type: 'application/json; charset=utf-8'})
    end

    it 'requests the correct resource' do
      @set.website('https://github.com/sferik')
      expect(a_post('/1.1/account/update_profile.json').with(body: {url: 'https://github.com/sferik'})).to have_been_made
    end

    it 'has the correct output' do
      @set.website('https://github.com/sferik')
      expect($stdout.string.chomp).to eq "@testcli's website has been updated."
    end
  end
end
