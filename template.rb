# GEMS

gem_group :test do
  gem 'capybara'
  gem 'capybara-screenshot'
  gem 'chromedriver-helper'
  gem 'factory_bot_rails'
  gem 'selenium-webdriver'
  gem 'site_prism'
  gem 'vcr'
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
  rails_command 'haml:erb2haml' # Setting HAML_RAILS_DELETE_ERB=true does not have an effect, it will still prompt

  # rails_command 'generate rspec:install'
  # run 'echo "--format documentation" >> .rspec'

  git :init
  git add: '.'
  git commit: %( -m 'Rails project set up with Boost template' )
end
