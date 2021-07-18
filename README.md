# Censorius

Censorius is a small gem that generates deterministic and stable UUID paths for [Xcodeproj](https://github.com/CocoaPods/Xcodeproj). It's meant to be used either with [CocoaPods](https://github.com/CocoaPods/CocoaPods) or [Xcake](https://github.com/igor-makarov/xcake) to reduce meaningless Xcode project file modifications, and therefore make Xcode incremental builds after project generation shorter.

## Installation

Add this line to your Gemfile:

```ruby
gem 'censorius'
```

## Usage

### With CocoaPods

In your `Podfile`:
```ruby
require 'censorius'
#
# Define your dependencies...
#
post_install do |installer|
  installer.generated_projects.each do |project|
    Censorius::UUIDGenerator.new([project]).generate!
  end
end
```

### With Xcake
In your `Cakefile`:
```ruby
require 'censorius'
#
# Define your targets...
#
project.before_save do |main_project|
  Censorius::UUIDGenerator.new([main_project]).generate!
end

```
## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/igor-makarov/censorius. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/igor-makarov/censorius/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Censorius project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/igor-makarov/censorius/blob/master/CODE_OF_CONDUCT.md).
