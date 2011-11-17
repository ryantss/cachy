Usage: include this module into any class you want to cache.

Example:

```ruby
class Tweet < ActiveRecord::Base
  include Cachy

  def expensive_method(params)
    # do some expensive tasks here
  end

  # You can cache the instance method.
  caches_method :expensive_method

  def another_expensive_method(params)
    # do some expensive tasks here
  end

  # You can cache many instance methods with optional cache options.
  caches_methods :expensive_method, :another_expensive_method, :expires_in => 1.hour

  module ClassMethods
    def find_with_conditions(params)
      # execute your big action here.
    end
  end

  extend Tweet::ClassMethods

  # You can cache the class method.
  caches_class_method :find_with_conditions

  # You can cache many class methods in one go.
  caches_class_methods :first, :all, :find_by_id, :expires_in => 1.hour

  # And cool part is.
  caches_class_methods :find_by_id, :first, :all do |*params|
    { :params => params, :scope => self.scoped.to_sql }
  end
  # This will cache all kind of query, e.g.
  # Tweet.where(:id => 10).first
  # Tweet.select('tweets.id, users.id, users.name').joins(:users).where(:id => 10).all

end
```