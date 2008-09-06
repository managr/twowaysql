class TwoWaySQL::Parser

rule

sql            : stmt_list
                {
                  result = RootNode.new( val[0] )
                }

stmt_list      :
                {
                  result = []
                }
               | stmt_list stmt
                {
                  result.push val[1]
                }

stmt           : primary
               | if_stmt
               | begin_stmt

begin_stmt     : BEGIN stmt_list END
                {
                  result = BeginNode.new( val[1] )
                }

if_stmt        : IF sub_stmt else_stmt END
                {
                  result = IfNode.new( val[0], val[1], val[2] )
                }

else_stmt      : ELSE sub_stmt
                {
                  result = val[1]
                }
               |
                {
                  result = nil
                }

sub_stmt       : and_stmt
               | or_stmt
               | stmt_list

and_stmt       : AND stmt_list
                {
                  result = SubStatementNode.new( val[0], val[1] )
                }

or_stmt        : OR stmt_list
                {
                  result = SubStatementNode.new( val[0], val[1] )
                }

primary        : IDENT
                {
                  result = LiteralNode.new( val[0] )
                }
               | STRING_LITERAL
                {
                  result = LiteralNode.new( val[0] )
                }
               | AND
                {
                  result = LiteralNode.new( val[0] )
                }
               | OR
                {
                  result = LiteralNode.new( val[0] )
                }
               | SPACES
                {
                  result = LiteralNode.new( val[0] )
                }
               | COMMA
                {
                  result = LiteralNode.new( val[0] )
                }
               | LPAREN
                {
                  result = LiteralNode.new( val[0] )
                }
               | RPAREN
                {
                  result = LiteralNode.new( val[0] )
                }
               | QUESTION
                {
                  @num_questions += 1
                  result = QuestionNode.new( @num_questions )
                }
               | ACTUAL_COMMENT
                {
                  result = CommentNode.new( val[0] )
                }
               | EOL
                {
                  result = EolNode.new
                }
               | bind_var
               | embed_var

bind_var       : BIND_VARIABLE STRING_LITERAL
                {
                  result = BindVariableNode.new( val[0] )
                }
               | BIND_VARIABLE SPACES STRING_LITERAL
                {
                  result = BindVariableNode.new( val[0] )
                }
               | BIND_VARIABLE IDENT
                {
                  result = BindVariableNode.new( val[0] )
                }
               | BIND_VARIABLE SPACES IDENT
                {
                  result = BindVariableNode.new( val[0] )
                }
               | PAREN_BIND_VARIABLE
                {
                  result = ParenBindVariableNode.new( val[0] )
                }

embed_var      : EMBED_VARIABLE IDENT
                {
                  result = EmbedVariableNode.new( val[0] )
                }
               | EMBED_VARIABLE SPACES IDENT
                {
                  result = EmbedVariableNode.new( val[0] )
                }

end


---- inner

require 'strscan'

def initialize(opts={})
  opts = {
    :debug => true,
    :preserve_space => true,
    :preserve_comment => true,
    :preserve_eol => true
  }.merge(opts)
  @yydebug = opts[:debug]
  @preserve_space = opts[:preserve_space]
  @preserve_comment = opts[:preserve_comment]
  @preserve_eol = opts[:preserve_eol]
  @num_questions = 0
end


PAREN_EXAMPLE                = '\([^\)]+\)'
BEGIN_BIND_VARIABLE          = '(\/|\#)\*([^\*]+)\*\1'
BIND_VARIABLE_PATTERN        = /\A#{BEGIN_BIND_VARIABLE}\s*/
PAREN_BIND_VARIABLE_PATTERN  = /\A#{BEGIN_BIND_VARIABLE}\s*#{PAREN_EXAMPLE}/
EMBED_VARIABLE_PATTERN       = /\A(\/|\#)\*\$([^\*]+)\*\1\s*/

CONDITIONAL_PATTERN   = /\A(\/|\#)\*(IF)\s+([^\*]+)\s*\*\1/
BEGIN_END_PATTERN     = /\A(\/|\#)\*(BEGIN|END)\s*\*\1/
STRING_LITERAL_PATTERN = /\A(\'(?:[^\']+|\'\')*\')/   ## quoted string
SPLIT_TOKEN_PATTERN   = /\A(\S+?)(?=\s*(?:(?:\/|\#)\*|-{2,}|\(|\)|\,))/  ## stop on delimiters --,/*,#*,',',(,)
ELSE_PATTERN          = /\A\-{2,}\s*ELSE\s*/
AND_PATTERN           = /\A(\s*AND\s+)/i
OR_PATTERN            = /\A(\s*OR\s+)/i
LITERAL_PATTERN       = /\A([^;\s]+)/
SPACES_PATTERN        = /\A(\s+)/
QUESTION_PATTERN      = /\A\?/
COMMA_PATTERN         = /\A\,/
LPAREN_PATTERN        = /\A\(/
RPAREN_PATTERN        = /\A\)/
ACTUAL_COMMENT_PATTERN          = /\A(\/|\#)\*\s+(.+)\s*\*\1/  ## start with spaces
SEMICOLON_AT_INPUT_END_PATTERN  = /\A\;\s*\Z/
UNMATCHED_COMMENT_START_PATTERN = /\A(?:(?:\/|\#)\*)/


def parse( io )
  @q = []
  io.each_line do |line|
    s = StringScanner.new(line.rstrip)
    until s.eos? do
      case
      when s.scan(AND_PATTERN)
        @q.push [ :AND, s[1] ]
      when s.scan(OR_PATTERN)
        @q.push [ :OR, s[1] ]
      when s.scan(SPACES_PATTERN)
        @q.push [ :SPACES, s[1] ] if @preserve_space
      when s.scan(QUESTION_PATTERN)
        @q.push [ :QUESTION, nil ]
      when s.scan(COMMA_PATTERN)
        @q.push [ :COMMA, ',' ]
      when s.scan(LPAREN_PATTERN)
        @q.push [ :LPAREN, '(' ]
      when s.scan(RPAREN_PATTERN)
        @q.push [ :RPAREN, ')' ]
      when s.scan(ELSE_PATTERN)
        @q.push [ :ELSE, nil ]
      when s.scan(ACTUAL_COMMENT_PATTERN)
        @q.push [ :ACTUAL_COMMENT, s[2] ] if @preserve_comment
      when s.scan(BEGIN_END_PATTERN)
        @q.push [ s[2].intern, nil ]
      when s.scan(CONDITIONAL_PATTERN)
        @q.push [ s[2].intern, s[3] ]
      when s.scan(EMBED_VARIABLE_PATTERN)
        @q.push [ :EMBED_VARIABLE, s[2] ]
      when s.scan(PAREN_BIND_VARIABLE_PATTERN)
        @q.push [ :PAREN_BIND_VARIABLE, s[2] ]
      when s.scan(BIND_VARIABLE_PATTERN)
        @q.push [ :BIND_VARIABLE, s[2] ]
      when s.scan(STRING_LITERAL_PATTERN)
        @q.push [ :STRING_LITERAL, s[1] ]
      when s.scan(SPLIT_TOKEN_PATTERN)
        @q.push [ :IDENT, s[1] ]
      when s.scan(UNMATCHED_COMMENT_START_PATTERN)   ## unmatched comment start, '/*','#*'
        raise Racc::ParseError, "## unmatched comment. cannot parse [#{s.rest}]"
      when s.scan(LITERAL_PATTERN)   ## other string token
        @q.push [ :IDENT, s[1] ]
      when s.scan(SEMICOLON_AT_INPUT_END_PATTERN)
        #drop semicolon at input end
      else
        raise Racc::ParseError, "## cannot parse [#{s.rest}]"
      end
    end
      
    @q.push [ :EOL, nil ] if @preserve_eol
  end
    
  @q.push [ false, nil ]
    
  ## cal racc's private parse method
  do_parse
end

def next_token
  @q.shift
end
