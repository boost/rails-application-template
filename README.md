# Boost Rails Application Template

## Setup

To set up a new project:
```ruby
rails new project_name -d mysql --skip-spring -m path/to/template.rb
# OR
rails new project_name -d mysql --skip-sping -m https://raw.githubusercontent.com/boost/rails-application-template/master/template.rb
```

To apply to an existing project:
```ruby
bin/rails app:template LOCATION=path/to/template.rb
```

## Features

This template does the following:

- Install GEMS WE LOVE
- Basic Travis configuration
- Configure the Rubocop
- Remove Turbolinks and CoffeeScript from Gemfile, and from views
- Convert ERB to HAML
- Configure Rspec
  - Configure Factory Bot
  - Configure Capybara
  - Configure Capybara screenshot
  - Configure Site Prism
  - Configure VCR
- Install and configure Foundation

## Reference

* Rails Guides: [Rails Application Templates](https://guides.rubyonrails.org/rails_application_templates.html)
