#!/usr/bin/ruby

# global constants.
WORD_DICT = 'chinese'
CHAR_DICT = 'characters'
GRAMMAR_LIST = 'grammar'
LOG_FILE = 'chinese.log'
CHINESE_REG = 'chinese.reg'
ENGLISH_REG = 'english.reg'

if $0 == __FILE__

  mode = process_args(ARGV)
  selection = selection.new(mode)
  results = results.new(mode)
  selection.each do |question|
    result = question.ask
    result.log
  end

end
