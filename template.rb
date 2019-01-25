# GEMS

gem_group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'chromedriver-helper'
  gem 'factory_bot_rails'
  gem 'selenium-webdriver'
  gem 'site_prism'
  gem 'vcr'
  gem 'webmock'
end

gem_group :development, :test do
  gem 'pry-rails'
  gem 'rspec-rails', '~> 3.8'
end

gem 'sprockets-es6'
gem 'foundation-rails'
gem 'haml-rails'

# TRAVIS

file '.travis.yaml', <<-CODE
sudo: required

language: ruby

stages:
- lint
- test

addons:
  chrome: stable

cache: bundler

jobs:
include:
  - stage: lint
    script:
      - rubocop
  - stage: test
    script:
      - bundle exec rspec

CODE

# RUBOCOP

file '.rubocop.yaml', <<-CODE
AllCops:
  Exclude:
  - 'Gemfile'
  - 'bin/**/*'
  - 'config/**/*'
  - 'db/**/*'
  - 'spec/**/**/**/*'

Style/Documentation:
  Enabled: false

Metrics/LineLength:
  Max: 120

Metrics/AbcSize:
  Max: 20

CODE

# DELETE MINITEST

run 'rm -rf test/'

# AFTER INITIAL PROJECT SETUP

after_bundle do
  # ______ Install things _______
  # rails_command 'haml:erb2haml' # Setting HAML_RAILS_DELETE_ERB=true does not have an effect, it will still prompt
  run 'spring stop'
  rails_command 'generate rspec:install'

  # ______ Configure Rspec _______
  run 'echo "--format documentation" >> .rspec'

  IO.write('spec/rails_helper.rb', File.open('spec/rails_helper.rb') do |f|
      f.read.gsub('# Dir[Rails.root.join(\'spec\', \'support\', \'**\', \'*.rb\')].each { |f| require f }', 'Dir[Rails.root.join(\'spec\', \'support\', \'**\', \'*.rb\')].each { |f| require f }')
    end
  )

  # ______ Configure factory bot _______
  file 'spec/support/factory_bot.rb', <<-'CODE'
# frozen_string_literal: true

require 'factory_bot_rails'

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
  CODE

  # ______ Configure capybara _______

  file 'spec/support/capybara.rb', <<-'CODE'
require 'selenium/webdriver'
require 'capybara'
require 'capybara/rspec'

Capybara.register_driver :headless_chrome do |app|

  options = Selenium::WebDriver::Chrome::Options.new(
    args: %w[headless disable-gpu no-sandbox]
  )
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :headless_chrome
  CODE

  # ______ Configure capybara screenshot _______
  file 'spec/support/capybara_screenshot.rb', <<-'CODE'
require 'capybara-screenshot/rspec'

Capybara::Screenshot.autosave_on_failure = true
Capybara.asset_host = 'http://localhost:3000'

Capybara::Screenshot.webkit_options = { width: 1440, height: 900 }
Capybara::Screenshot.register_filename_prefix_formatter(:rspec) do |example|
  "screenshot_#{example.description.tr(' ', '-').gsub(%r{^.*\/spec\/}, '')}"
end
Capybara::Screenshot.prune_strategy = :keep_last_run
Capybara::Screenshot.register_driver(:headless_chrome) do |driver, path|
  driver.browser.save_screenshot(path)
end
  CODE


  # ______ Configure site prism _______
  file 'spec/support/site_prism.rb', <<-'CODE'
require 'site_prism'

Dir[Rails.root.join('spec/page_objects/**/*.rb')].sort { |path| path.include?('shared') ? 0 : 1 }
                                                 .each { |f| require f }
  CODE

  file 'spec/page_objects/shared/layout_page.rb', <<-'CODE'
class LayoutPage < SitePrism::Page
end
  CODE

  file "spec/page_objects/#{@app_name}_site.rb", <<-CODE
class #{@app_name.capitalize}Site < SitePrism::Page
  # example page (reads from an example file called spec/page_objects/process_page.rb)
  # def process_page
  #   @process_page ||= ProcessPage.new
  # end
end
  CODE

  # ______ Configure VCR _______
  file 'spec/support/vcr.rb', <<-'CODE'
require 'webmock/rspec'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.ignore_localhost = true
  config.allow_http_connections_when_no_cassette = true
  config.default_cassette_options = {
    record: :new_episodes,
    allow_playback_repeats: true
  }
end
  CODE

  # ______ Configure git and commit  _______
  git :init
  git add: '.'
  git commit: %( -m 'Rails project set up with Boost template' )
end
