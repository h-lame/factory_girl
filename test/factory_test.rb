require(File.join(File.dirname(__FILE__), 'test_helper'))

class FactoryTest < Test::Unit::TestCase

  def self.should_instantiate_class

    should "instantiate the build class" do
      assert_kind_of @class, @instance
    end

    should "assign attributes on the instance" do
      assert_equal @first_name, @instance.first_name
      assert_equal @last_name,  @instance.last_name
    end

    should "override attributes using the passed hash" do
      @value = 'Davis'
      @instance = @factory.build(:first_name => @value)
      assert_equal @value, @instance.first_name
    end

  end

  context "defining a factory" do

    setup do
      @name    = :user
      @factory = mock('factory')
      @options = { :class => 'magic' }
      Factory.stubs(:new).returns(@factory)
    end

    should "create a new factory using the specified name and options" do
      Factory.expects(:new).with(@name, @options)
      Factory.define(@name, @options) {|f| }
    end

    should "pass the factory do the block" do
      yielded = nil
      Factory.define(@name) do |y|
        yielded = y
      end
      assert_equal @factory, yielded
    end

    should "add the factory to the list of factories" do
      Factory.define(@name) {|f| }
      assert_equal Factory.factories[@name], 
                   @factory,
                   "Factories: #{Factory.factories.inspect}"
    end

  end

  context "defining a sequence" do

    setup do
      @sequence = mock('sequence')
      @name     = :count
      Factory::Sequence.stubs(:new).returns(@sequence)
    end

    should "create a new sequence" do
      Factory::Sequence.expects(:new).with().returns(@sequence)
      Factory.sequence(@name)
    end

    should "use the supplied block as the sequence generator" do
      Factory::Sequence.stubs(:new).yields(1)
      yielded = false
      Factory.sequence(@name) {|n| yielded = true }
      assert yielded
    end

  end

  context "a factory" do

    setup do
      @name    = :user
      @class   = User
      @factory = Factory.new(@name)
    end

    should "have a name" do
      assert_equal @name, @factory.name
    end

    should "have a build class" do
      assert_equal @class, @factory.build_class
    end
    
    should "have a set of callbacks" do
      assert @factory.instance_eval {@callbacks}
    end

    should "have an empty set of callbacks when none have been set" do
      assert @factory.instance_eval {@callbacks.empty?}
    end

    context "when adding an after_build callback" do
      setup do
        @the_block = lambda{|u| }
        @factory.after_build &@the_block
      end

      should "have something in the set of callbacks" do
        assert_equal 1, @factory.instance_eval {@callbacks.size}
      end
      
      should "record the callback in the set of callbacks" do
        assert @factory.instance_eval {@callbacks.values}.include?(@the_block)
      end

      should "record the callback in the set of callbacks under the after_build key" do
        assert_equal @the_block, @factory.instance_eval {@callbacks[:after_build]}
      end
    end

    context "when adding an after_create callback" do
      setup do
        @the_block = lambda{|u| }
        @factory.after_create &@the_block
      end

      should "have something in the set of callbacks" do
        assert_equal 1, @factory.instance_eval {@callbacks.size}
      end
      
      should "record the callback in the set of callbacks" do
        assert @factory.instance_eval {@callbacks.values}.include?(@the_block)
      end

      should "record the callback in the set of callbacks under the after_create key" do
        assert_equal @the_block, @factory.instance_eval {@callbacks[:after_create]}
      end
    end

    context "when adding an attribute with a value parameter" do

      setup do
        @attr  = :name
        @value = 'Elvis lives!'
        @factory.add_attribute(@attr, @value)
      end

      should "include that value in the generated attributes hash" do
        assert_equal @value, @factory.attributes_for[@attr]
      end

    end

    context "when adding an attribute with a block" do

      setup do
        @attr  = :name
        @attrs = {}
        @proxy = mock('attr-proxy')
        Factory::AttributeProxy.stubs(:new).returns(@proxy)
      end

      should "not evaluate the block when the attribute is added" do
        @factory.add_attribute(@attr) { flunk }
      end

      should "evaluate the block when attributes are generated" do
        called = false
        @factory.add_attribute(@attr) do
          called = true
        end
        @factory.attributes_for
        assert called
      end

      should "use the result of the block as the value of the attribute" do
        value = "Watch out for snakes!"
        @factory.add_attribute(@attr) { value }
        assert_equal value, @factory.attributes_for[@attr]
      end

      should "build an attribute proxy" do
        Factory::AttributeProxy.expects(:new).with(@factory, @attr, :attributes_for, @attrs)
        @factory.add_attribute(@attr) {}
        @factory.attributes_for
      end

      should "yield an attribute proxy to the block" do
        yielded = nil
        @factory.add_attribute(@attr) {|y| yielded = y }
        @factory.attributes_for
        assert_equal @proxy, yielded
      end

      context "when other attributes have previously been defined" do
        
        setup do
          @attr  = :unimportant
          @attrs = {
            :one     => 'whatever',
            :another => 'soup'
          }
          @factory.add_attribute(:one, 'whatever')
          @factory.add_attribute(:another) { 'soup' }
          @factory.add_attribute(@attr) {}
        end

        should "provide previously set attributes" do
          Factory::AttributeProxy.expects(:new).with(@factory, @attr, :attributes_for, @attrs)
          @factory.attributes_for
        end

      end

    end

    should "add an attribute using the method name when passed an undefined method" do
      @attr  = :first_name
      @value = 'Sugar'
      @factory.send(@attr, @value)
      assert_equal @value, @factory.attributes_for[@attr]
    end

    should "not allow attributes to be added with both a value parameter and a block" do
      assert_raise(ArgumentError) do
        @factory.add_attribute(:name, 'value') {}
      end
    end

    context "when overriding generated attributes with a hash" do

      setup do
        @attr  = :name
        @value = 'The price is right!'
        @hash  = { @attr => @value }
      end

      should "return the overridden value in the generated attributes" do
        @factory.add_attribute(@attr, 'The price is wrong, Bob!')
        assert_equal @value, @factory.attributes_for(@hash)[@attr]
      end

      should "not call a lazy attribute block for an overridden attribute" do
        @factory.add_attribute(@attr) { flunk }
        @factory.attributes_for(@hash)
      end

    end

    should "guess the build class from the factory name" do
      assert_equal User, @factory.build_class
    end

    context "when defined with a custom class" do

      setup do
        @class   = User
        @factory = Factory.new(:author, :class => @class)
      end

      should "use the specified class as the build class" do
        assert_equal @class, @factory.build_class
      end

    end

    context "with some attributes added" do

      setup do
        @first_name = 'Billy'
        @last_name  = 'Idol'
        @email      = 'test@something.com'

        @factory.add_attribute(:first_name, @first_name)
        @factory.add_attribute(:last_name,  @last_name)
        @factory.add_attribute(:email,      @email)
      end

      context "and an after_build callback has been registered" do
        setup do
          @the_block = lambda {|user| assert user.new_record?; @saved = user}
          
          @factory.after_build &@the_block
        end
        
        should "call the callback when the object is built" do
          @the_block.expects(:call).once
          @factory.build
        end

        should "call the callback when the object is created" do
          @the_block.expects(:call).once
          @factory.create
        end

        should "yield the instance to the callback when called" do
          instance = @factory.build
          assert_equal @saved, instance
        end
      end

      context "and an after_create callback has been registered" do
        setup do
          @the_block = lambda {|user| assert !user.new_record?; @saved = user}
          
          @factory.after_create &@the_block
        end
        
        should "not call the callback when the object is built" do
          @the_block.expects(:call).never
          @factory.build
        end

        should "call the callback when the object is created" do
          @the_block.expects(:call).once
          @factory.create
        end

        should "yield the instance to the callback when called" do
          instance = @factory.create
          assert_equal @saved, instance
        end
      end

      context "and both after_build and after_create callbacks have been registered" do
        setup do
          @the_after_build_block = lambda {|user| assert user.new_record?; @post_build = user}
          @the_after_create_block = lambda {|user| assert !user.new_record?; @post_create = user}
          
          @factory.after_build &@the_after_build_block
          @factory.after_create &@the_after_create_block
        end
        
        should "only call the after_build callback when the object is built" do
          @the_after_build_block.expects(:call).once
          @the_after_create_block.expects(:call).never
          @factory.build
        end

        should "call both callbacks when the object is created" do
          @the_after_build_block.expects(:call).once
          @the_after_create_block.expects(:call).once
          @factory.create
        end

        should "yield the same instance to each callback when called" do
          instance = @factory.create
          assert_equal @post_build, instance
          assert_equal @post_create, instance
          assert_equal @post_create, @post_build
        end
        
        should "call the after_build callback before the after_create callback when objects are created" do
          # TODO - is this good enough to detect "beforeness"?
          @the_after_build_block = lambda {|user| assert_nil @post_build; assert_nil @post_create; @post_build = user}
          @the_after_create_block = lambda {|user| assert_not_nil @post_build; assert_nil @post_create; @post_create = user}
          
          @factory.after_build &@the_after_build_block
          @factory.after_create &@the_after_create_block
          @factory.create
        end
      end

      context "when building an instance" do

        setup do
          @instance = @factory.build
        end

        should_instantiate_class

        should "not save the instance" do
          assert @instance.new_record?
        end

      end
      
      context "when creating an instance" do

        setup do
          @instance = @factory.create
        end

        should_instantiate_class

        should "save the instance" do
          assert !@instance.new_record?
        end

      end

      should "raise an ActiveRecord::RecordInvalid error for invalid instances" do
        assert_raise(ActiveRecord::RecordInvalid) do
          @factory.create(:first_name => nil)
        end
      end

    end

  end

  context "Factory class" do

    setup do
      @name       = :user
      @attrs      = { :last_name => 'Override' }
      @first_name = 'Johnny'
      @last_name  = 'Winter'
      @class      = User

      Factory.define(@name) do |u|
        u.first_name @first_name
        u.last_name  { @last_name }
        u.email      'jwinter@guitar.org'
      end

      @factory = Factory.factories[@name]
    end

    [:build, :create, :attributes_for].each do |method|

      should "delegate the #{method} method to the factory instance" do
        @factory.expects(method).with(@attrs)
        Factory.send(method, @name, @attrs)
      end

      should "raise an ArgumentError when #{method} is called with a nonexistant factory" do
        assert_raise(ArgumentError) { Factory.send(method, :bogus) }
      end

    end

    should "call the create method from the top-level Factory() method" do
      @factory.expects(:create).with(@attrs)
      Factory(@name, @attrs)
    end

  end

  context "after defining a sequence" do

    setup do
      @sequence = mock('sequence')
      @name     = :test
      @value    = '1 2 5'

      @sequence.        stubs(:next).returns(@value)
      Factory::Sequence.stubs(:new). returns(@sequence)

      Factory.sequence(@name) {}
    end

    should "call next on the sequence when sent next" do
      @sequence.expects(:next)

      Factory.next(@name)
    end

    should "return the value from the sequence" do
      assert_equal @value, Factory.next(@name)
    end

  end

end
