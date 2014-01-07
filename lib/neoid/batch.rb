module Neoid
  class Batch
    def default_options=(value)
      @default_options = value
    end

    def self.default_options
      @default_options ||= { batch_size: 200, individual_promises: true }
    end

    def self.current_batch
      Thread.current[:neoid_current_batch]
    end

    def self.current_batch=(batch)
      Thread.current[:neoid_current_batch] = batch
    end

    def self.reset_current_batch
      Thread.current[:neoid_current_batch] = nil
    end

    def initialize(instance, options={}, &block)
      if options.respond_to?(:call) && !block
        block = options
        options = {}
      end

      options.reverse_merge!(self.class.default_options)

      @instance = instance
      @options = options
      @block = block
    end

    def <<(command)
      commands << command

      if commands.length >= @options[:batch_size]
        flush_batch
      end

      if @options[:individual_promises]
        promise = SingleResultPromiseProxy.new(command)
        thens << promise
        promise
      end
    end

    def commands
      @commands ||= []
    end

    def thens
      @thens ||= []
    end

    def count
      @commands ? @commands.count : 0
    end

    def results
      @results ||= []
    end

    def run
      self.class.current_batch = self

      begin
        @block.call(self)
      ensure      
        self.class.reset_current_batch
      end

      @instance.logger.info "Neoid batch (#{commands.length} commands)"

      flush_batch

      BatchPromiseProxy.new(results)
    end

    private
      def flush_batch
        return [] if commands.empty?
        current_results = nil

        # results = @instance.db.batch(*commands).collect { |result| result['body'] }

        benchmark = Benchmark.measure {
          current_results = @instance.db.batch(*commands).collect { |result| result['body'] }
        }
        @instance.logger.info "Neoid batch (#{commands.length} commands) - #{benchmark}"
        commands.clear

        process_results(current_results)

        thens.zip(current_results).each { |t, result| t.perform(result) }

        thens.clear

        results.concat current_results
      end

      def process_results(results)
        results.map! do |result|
          return result unless result.is_a?(Hash) && result['self'] && result['self'][%r[^https?://.*/(node|relationship)/\d+]]

          type = case $1
          when 'node' then Neoid::Node
          when 'relationship' then Neoid::Relationship
          else return result
          end

          type.from_hash(result)
        end
      end
  end

  # returned from a full batch, after it has been executed,
  # so a `.then` can be chained after the batch do ... end
  # it proxies all methods to the result
  class BatchPromiseProxy
    def initialize(results)
      @results = results
    end

    def method_missing(method, *args)
      @results.send(method, *args)
    end

    def then
      yield(@results)
    end
  end

  # returned from adding (<<) an item to a batch in a batch block:
  # @instance.batch { |batch| (batch << [:neography_command, param]).is_a?(SingleResultPromiseProxy) }
  # so a `.then` can be chained:
  # @instance.batch { |batch| (batch << [:neography_command, param]).then { |result| puts result } }
  # the `then` is called once the batch is flushed with the result of the single job in the batch
  # it proxies all methods to the result, so in case it is returned (like in @instance.execute_script_or_add_to_batch)
  # the result of the method will be proxied to the result from the batch. See Node#neo_save
  class SingleResultPromiseProxy
    def initialize(*args)
    end

    attr_accessor :result

    def result
      raise "Accessed result too soon" unless @result
      @result
    end

    def method_missing(method, *args)
      result.send(method, *args)
    end

    def then(&block)
      @then = block
      self
    end

    def perform(result)
      @result = result
      return unless @then
      @then.call(result)
    end
  end
end
