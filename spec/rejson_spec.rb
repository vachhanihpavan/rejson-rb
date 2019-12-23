# frozen_string_literal: true

require "rejson/path"
require "rejson/client"
require "spec_helper"
require "json"

describe "Test ReJSON" do
  rcl = Redis.new(db: 14)

  docs = {
    'simple': {
      'foo': "bar"
    },
    'basic': {
      'string': "string value",
      'nil': nil,
      'bool': true,
      'int': 42,
      'num': 4.2,
      'arr': [42, nil, -1.2, false, %w[sub array], { 'subdict': true }],
      'dict': {
        'a': 1,
        'b': "2",
        'c': nil
      }
    },
    'scalars': {
      'unicode': "string value",
      'NoneType': nil,
      'bool': true,
      'int': 42,
      'float': -1.2
    },
    'values': {
      'unicode': "string value",
      'NoneType': nil,
      'bool': true,
      'int': 42,
      'float': -1.2,
      'dict': {},
      'list': []
    },
    'types': {
      'null': nil,
      'boolean': false,
      'integer': 42,
      'number': 1.2,
      'string': "str",
      'object': {},
      'array': []
    }
  }

  before :all do
    rcl.flushdb
  end

  context "test rejson get/set" do
    it "gets a blank value" do
      foo = rcl.json_get "foo"
      foo.should be_nil
    end

    it "sets a value" do
      set = rcl.json_set "foo", Rejson::Path.root_path, "bar"
      set.should eq "OK"
    end

    it "gets a value" do
      foo = rcl.json_get "foo"
      foo.should eq "bar"
    end

    it "gets a value (w/ p)" do
      foo = rcl.json_get "foo", "."
      foo.should eq "bar"
    end

    it "test full get/set with datatypes" do
      set = rcl.json_set "foo", Rejson::Path.root_path, docs["basic"]
      set.should eq "OK"

      foo = rcl.json_get "foo", "."
      foo.should eq docs["basic"]

      set = rcl.json_set "foo", Rejson::Path.root_path, docs["scalars"]
      set.should eq "OK"

      foo = rcl.json_get "foo", "."
      foo.should eq docs["scalars"]

      set = rcl.json_set "foo", Rejson::Path.root_path, docs["types"]
      set.should eq "OK"

      foo = rcl.json_get "foo", "."
      foo.should eq docs["types"]

      set = rcl.json_set "foo", Rejson::Path.root_path, docs["values"]
      set.should eq "OK"

      foo = rcl.json_get "foo", "."
      foo.should eq docs["values"]
    end

    it "tests get/set with path" do
      set = rcl.json_set "test", ".", {}
      set.should eq "OK"
      set = rcl.json_set "test", Rejson::Path.new(".foo"), "baz"
      set.should eq "OK"
      set = rcl.json_set "test", ".bar", "qux"
      set.should eq "OK"
      get = rcl.json_get "test"
      get.should == { "bar" => "qux", "foo" => "baz" }
    end

    it "should do get/set with nx/xx flags" do
      set = rcl.json_set "test", ".", foo: "bar"
      set.should eq "OK"
      set = rcl.json_set "test", "foo", "baz", nx: true
      set.should_not eq "OK"
      set = rcl.json_set "test", "bar", "baz", xx: true
      set.should_not eq "OK"
      set = rcl.json_set "test", "foo", "bam", xx: true
      set.should eq "OK"
      set = rcl.json_set "test", "bar", "baz", nx: true
      set.should eq "OK"

      expect do
        begin
                 rcl.json_set "test", "foo", "baz", nx: true, xx: true
        rescue StandardError
          Exception
               end
      end
      get = rcl.json_get "test", "foo"
      get.should_not eq "baz"
    end

    it "deletes a values" do
      foo = rcl.json_del "foo"
      foo.should eq 0

      foo = rcl.json_get "foo"
      foo.should eq nil
    end

    it "mgets a value" do
      set = rcl.json_set "foo1", Rejson::Path.root_path, "bar1"
      set.should eq "OK"

      set = rcl.json_set "foo2", Rejson::Path.root_path, "bar2"
      set.should eq "OK"

      foo = rcl.json_mget "foo1", "foo2", "."
      foo.should eq %w[bar1 bar2]
    end

    it "gets type" do
      type = rcl.json_type "test", "."
      type.should eq "object"
    end
  end

  context "tests number manipulation" do
    it "tests numicrby" do
      set = rcl.json_set "test", ".", "foo" => 0, "bar" => 1
      incr = rcl.json_numincrby "test", ".foo", 1
      incr.should eq 1
      get = rcl.json_get "test"
      get.should == { "foo" => 1, "bar" => 1 }
    end

    it "tests nummultby" do
      incr = rcl.json_nummultby "test", ".bar", 2
      incr.should eq 2
      get = rcl.json_get "test"
      get.should == { "foo" => 1, "bar" => 2 }
    end
  end

  context "test string manipulation" do
    it "tests string append" do
      rcl.json_set "test", ".", "foo"
      append = rcl.json_strappend("test", "bar")
      append.should eq 6
      get = rcl.json_get "test"
      get.should == "foobar"
    end

    it "tests string string length" do
      length = rcl.json_strlen("test")
      length.should be 6
    end
  end

  context "test array manipulation" do
    it "should append to array" do
      rcl.json_set "test", ".", docs[:basic]
      new_length = rcl.json_arrappend "test", ".arr", 42
      new_length.should be 7
    end

    it "should return index of array" do
      rcl.json_set "test", ".", "arr" => [0, 1, 2, 3, 2, 1, 0]
      element = rcl.json_arrindex "test", ".arr", 3
      element.should eq 3
    end

    it "should insert element in array" do
      rcl.json_set "test", ".", "arr" => [0, 1, 2, 3]
      element = rcl.json_arrinsert "test", ".arr", 2, "str"
      element.should eq 5
      get = rcl.json_get "test"
      get.should == { "arr" => [0, 1, "str", 2, 3] }
    end

    it "should get length of array" do
      rcl.json_set "test", ".", "arr" => [0, 1, 2, 3]
      length = rcl.json_arrlen "test", ".arr"
      length.should eq 4
    end

    it "should pop element from array" do
      rcl.json_set "test", ".", "arr" => [0, 1, 2, 3]
      popped = rcl.json_arrpop "test", ".arr", 2
      popped.should eq "2"
    end

    it "should trim array" do
      rcl.json_set "test", ".", "arr": [0, 1, 2, 3, 2, 1, 0]
      trimmed = rcl.json_arrtrim "test", ".arr", 1, -2
      trimmed.should eq 5
      trimmed_list = rcl.json_get "test", ".arr"
      trimmed_list.should eq [1, 2, 3, 2, 1]
      trimmed = rcl.json_arrtrim "test", ".arr", 0, 99
      trimmed.should eq 5
      trimmed = rcl.json_arrtrim "test", ".arr", 0, 2
      trimmed_list = rcl.json_get "test", ".arr"
      trimmed_list.should eq [1, 2, 3]
      trimmed.should eq 3
    end
  end

  context "test object manipulation" do
    it "should return keys of object" do
      rcl.json_set "test", ".", docs
      length = rcl.json_objkeys "test", ".types"
      length.should eq docs[:types].keys.map(&:to_s)
      length = rcl.json_objkeys "test"
      length.should eq docs.keys.map(&:to_s)
    end

    it "should return length of object" do
      rcl.json_set "test", ".", docs
      length = rcl.json_objlen "test", ".types"
      length.should eq docs[:types].keys.size
      length = rcl.json_objlen "test"
      length.should eq docs.keys.size
    end
  end

  context "test remaining stuff" do
    it "should return resp format" do
      rcl.json_set "test", ".", nil
      resp = rcl.json_resp "test"
      resp.should eq nil
      rcl.json_set "test", ".", true
      resp = rcl.json_resp "test"
      resp.should eq "true"
      rcl.json_set "test", ".", 2.5
      resp = rcl.json_resp "test"
      resp.should eq "2.5"
      rcl.json_set "test", ".", 42
      resp = rcl.json_resp "test"
      resp.should eq 42
      expect(rcl.json_set("test", ".", [1, 2])).to be == "OK"
      resp = rcl.json_resp "test"
      resp[0].should eq "["
      resp[1].should eq 1
      resp[2].should eq 2
    end
  end
end
