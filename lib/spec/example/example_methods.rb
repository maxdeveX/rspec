module Spec
  module Example
    module ExampleMethods
      
      extend ModuleReopeningFix
      
      def subject # :nodoc: this is somewhat experimental
        @subject ||= ( instance_variable_get(subject_variable_name) ||
                       instance_eval(&self.class.subject_block) ||
                       (described_class ? described_class.new : nil) )
      end

      # When +should+ is called with no explicit receiver, the call is
      # delegated to the *subject* of the example group. This could be either
      # an explicit subject generated by calling the block passed to
      # +ExampleGroupMethods#subject+, or, if the group is describing a class,
      # an implicitly generated instance of that class.
      def should(matcher=nil)
        if matcher
          subject.should(matcher)
        else
          subject.should
        end
      end

      # Just like +should+, +should_not+ delegates to the subject (implicit or
      # explicit) of the example group.
      def should_not(matcher)
        subject.should_not(matcher)
      end
      
      def violated(message="")
        raise Spec::Expectations::ExpectationNotMetError.new(message)
      end

      def description
        @_defined_description || ::Spec::Matchers.generated_description || "NO NAME"
      end
      
      def options
        @_options
      end

      def execute(options, instance_variables)
        options.reporter.example_started(self)
        set_instance_variables_from_hash(instance_variables)
        
        execution_error = nil
        Timeout.timeout(options.timeout) do
          begin
            before_each_example
            eval_block
          rescue Exception => e
            execution_error ||= e
          end
          begin
            after_each_example
          rescue Exception => e
            execution_error ||= e
          end
        end

        options.reporter.example_finished(self, execution_error)
        success = execution_error.nil? || ExamplePendingError === execution_error
      end

      def instance_variable_hash # :nodoc:
        instance_variables.inject({}) do |variable_hash, variable_name|
          variable_hash[variable_name] = instance_variable_get(variable_name)
          variable_hash
        end
      end

      def eval_each_fail_fast(examples) # :nodoc:
        examples.each do |example|
          instance_eval(&example)
        end
      end

      def eval_each_fail_slow(examples) # :nodoc:
        first_exception = nil
        examples.each do |example|
          begin
            instance_eval(&example)
          rescue Exception => e
            first_exception ||= e
          end
        end
        raise first_exception if first_exception
      end

      # Concats the class description with the example description.
      #
      #   describe Account do
      #     it "should start with a balance of 0" do
      #     ...
      #
      #   full_description
      #   => "Account should start with a balance of 0"
      def full_description
        "#{self.class.description} #{self.description}"
      end
      
      def set_instance_variables_from_hash(ivars) # :nodoc:
        ivars.each do |variable_name, value|
          # Ruby 1.9 requires variable.to_s on the next line
          unless ['@_implementation', '@_defined_description', '@_matcher_description', '@method_name'].include?(variable_name.to_s)
            instance_variable_set variable_name, value
          end
        end
      end

      def eval_block # :nodoc:
        instance_eval(&@_implementation)
      end

      # Provides the backtrace up to where this example was declared.
      def backtrace
        @backtrace
      end
      
      def implementation_backtrace
        Kernel.warn <<-WARNING
ExampleMethods#implementation_backtrace is deprecated and will be removed
from a future version. Please use ExampleMethods#backtrace instead.
WARNING
        backtrace
      end

      private
      include Matchers
      include Pending
      
      def before_each_example
        setup_mocks_for_rspec
        self.class.run_before_each(self)
      end

      def after_each_example
        self.class.run_after_each(self)
        verify_mocks_for_rspec
      ensure
        teardown_mocks_for_rspec
      end

      def subject_variable_name
        '@' << (described_class ? underscore(described_class.name) : '__this_does_not_exist')
      end
      
      def described_class
        Class === described_type ? described_type : nil
      end
      
      def described_type
        self.class.described_type
      end

      def underscore(camel_cased_word)
        camel_cased_word.to_s.gsub(/::/, '_').
          gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
          gsub(/([a-z\d])([A-Z])/,'\1_\2').
          tr("-", "_").
          downcase
      end
    end
  end
end
