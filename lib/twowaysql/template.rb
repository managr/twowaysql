require 'forwardable'

module TwoWaySQL

  # TwoWaySQL::Template represents template object, acts as a Facade for this package.
  # Template is stateless, reentrant object so template object is cacheable.
  class Template

    # parse TwoWaySQL-style SQL then return TwoWaySQL::Template object
    #
    # === Usage
    #
    #   sql = "SELECT * FROM emp WHERE job = /*ctx[:job]*/'CLERK' AND deptno = /*ctx[:deptno]*/20"
    #   template = TwoWaySQL::Template.parse(sql)
    #
    # === Arguments
    #
    # +sql_io+::
    #   IO-like object that contains TwoWaySQL-style SQL
    #
    # +opts+::
    #   (optional) Hash of parse options to pass internal lexer. default is empty hash.
    # 
    # === Return
    #
    # TwoWaySQL::Template object that represents parse result
    #
    def Template.parse(sql_io, opts={})
      parser = Parser.new(opts)
      root = parser.parse(sql_io)
      Template.new(root)
    end

    # merge data with template
    #
    # === Usage
    #
    #   merged = template.merge(:job => "HOGE", :deptno => 30)
    #   merged.sql                #=> "SELECT * FROM emp WHERE job = ? AND deptno = ?"
    #   merged.bound_variables    #=> ["HOGE", 30]
    #
    # === Arguments
    #
    # +data+::
    #   Hash-like object that contains data to merge. This data will evaluated as name 'ctx'.
    #
    # === Return
    #
    # TwoWaySQL::Result object that represents merge result
    #
    def merge(data)
      c = Context.new(data)
      @root.accept(c)
      Result.new(c)
    end
    alias mungle merge

    protected
    def initialize(root)
      @root = root
    end
  end


  # TwoWaySQL::Result represents merge result of template and data.
  # it contains SQL string with placeholders, and bound variables associated with placeholders.
  class Result
    extend Forwardable
    def initialize(context)
      @context = context
    end
    def_delegators :@context, :sql, :bound_variables
  end

end
