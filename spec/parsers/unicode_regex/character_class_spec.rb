# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'spec_helper'

include TwitterCldr::Parsers

describe UnicodeRegexParser::CharacterClass do
  let(:tokenizer) { UnicodeRegexTokenizer.new }
  let(:parser) { UnicodeRegexParser.new }

  def tokenize(str)
    tokenizer.tokenize(str)
  end

  def parse(tokens, options = {})
    parser.parse(tokens, options)
  end

  def char_class_from(elements)
    elements.first
  end

  describe "#to_set" do
    it "unions together char classes with no explicit operator" do
      char_class = char_class_from(parse(tokenize("[[a][b]]")))
      char_class.to_set.to_a.should == [97..98]
    end

    it "unions together other entities within char classes when operator is not explicit" do
      char_class = char_class_from(parse(tokenize("[a-z0-9\\u0123]")))
      char_class.to_set.to_a(true).should == [48..57, 97..122, 291]
    end

    it "intersects correctly" do
      char_class = char_class_from(parse(tokenize("[[a-m]&[g-z]]")))
      char_class.to_set.to_a.should == [103..109]
    end

    it "finds symmetric differences correctly" do
      char_class = char_class_from(parse(tokenize("[[a-m]-[g-z]]")))
      char_class.to_set.to_a.should == [97..102, 110..122]
    end

    it "computes sets for nested expressions" do
      # (97..109) U (104..106)
      # = (104..106)
      # ((104..106) U (107..122)) subtr ((104..106) C (107..122))
      # = (104..122) subtr ()
      # = (104..122)
      char_class = char_class_from(parse(tokenize("[[[a-m]&[h-j]]-[k-z]]")))
      char_class.to_set.to_a.should == [104..122]
    end

    it "pulls in ranges for unicode character sets" do
      char_class = char_class_from(parse(tokenize("[\\p{Zs}]")))
      char_class.to_set.to_a(true).should == [
        32, 160, 5760, 6158, 8192..8202, 8239, 8287, 12288
      ]
    end

    it "computes unions between unicode character sets" do
      char_class = char_class_from(parse(tokenize("[[\\p{Zs}][\\p{Cc}]]")))
      char_class.to_set.to_a(true).should == [
        0..1, 8..32, 127..160, 5760, 6158, 8192..8202, 8239, 8287, 12288
      ]
    end

    it "computes intersections between unicode character sets" do
      char_class = char_class_from(parse(tokenize("[[\\p{Zs}]&[\\u2000-\\u202B]]")))
      char_class.to_set.to_a(true).should == [8192..8202]
    end

    it "supports negating character sets" do
      char_class = char_class_from(parse(tokenize("[^\\u2000-\\u202B]")))
      char_class.to_set.to_a(true).should == [
        0..1, 8..8191, 8236..55295, 57344..1114111
      ]
    end

    it "supports literal and escaped characters" do
      char_class = char_class_from(parse(tokenize("[abc\\edf\\g]")))
      char_class.to_set.to_a(true).should == [97..103]
    end

    it "supports special switch characters" do
      char_class = char_class_from(parse(tokenize("[\\w]")))  # a-z, A-Z, 0-9, _
      char_class.to_set.to_a(true).should == [48..57, 65..90, 95, 97..122]
    end

    it "supports negated switch characters" do
      char_class = char_class_from(parse(tokenize("[\\D]")))  # i.e. NOT \w
      char_class.to_set.to_a(true).should == [
        0..1, 8..47, 58..55295, 57344..1114111
      ]
    end
  end

  describe "#to_regexp_str" do
    it "wraps ranges in square brackets" do
      char_class = char_class_from(parse(tokenize("[a-z]")))
      char_class.to_regexp_str.should == "(?:[\\141-\\172])"
    end

    it "octal-encodes and wraps sequential characters to isolate bytes" do
      char_class = char_class_from(parse(tokenize("[{foo}]")))
      char_class.to_regexp_str.should == "(?:(?:\\146)(?:\\157)(?:\\157))"
    end

    it "combines multiple components with 'or' pipe characters" do
      char_class = char_class_from(parse(tokenize("[{foo}abc]")))
      char_class.to_regexp_str.should == "(?:(?:\\146)(?:\\157)(?:\\157)|[\\141-\\143])"
    end
  end
end
