# frozen_string_literal: true

require "rejson/path"
require "rejson/client"
require "spec_helper"
require "json"

describe "Test ReJSON" do
  before :all do
    @rcl = Redis.new(db: 14)

    @docs = {
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
    @rcl.flushdb
  end

  context "get/set" do
    context "basic functionality" do
      it "gets a blank value" do
        foo = @rcl.json_get "foo"
        foo.should be_nil
      end

      it "sets a value" do
        set = @rcl.json_set "foo", Rejson::Path.root_path, "bar"
        set.should eq "OK"
      end

      it "gets a value" do
        foo = @rcl.json_get "foo"
        foo.should eq "bar"
      end

      it "gets a value (w/ p)" do
        foo = @rcl.json_get "foo", "."
        foo.should eq "bar"
      end
    end

    context "with all data types" do
      it "should be OK" do
        set = @rcl.json_set "foo", Rejson::Path.root_path, @docs[:basic]
        set.should eq "OK"

        foo = @rcl.json_get "foo", "."
        expect(foo).to(match({ "arr" => [42, nil, -1.2, false, %w[sub array], { "subdict" => true }],
                               "bool" => true, "dict" => { "a" => 1, "b" => "2", "c" => nil },
                               "int" => 42, "nil" => nil, "num" => 4.2, "string" => "string value" }))

        set = @rcl.json_set "foo", Rejson::Path.root_path, @docs[:scalars]
        set.should eq "OK"

        foo = @rcl.json_get "foo", "."
        foo.should eq @docs[:scalars].transform_keys(&:to_s)

        set = @rcl.json_set "foo", Rejson::Path.root_path, @docs[:types]
        set.should eq "OK"

        foo = @rcl.json_get "foo", "."
        foo.should eq @docs[:types].transform_keys(&:to_s)

        set = @rcl.json_set "foo", Rejson::Path.root_path, @docs[:values]
        set.should eq "OK"

        foo = @rcl.json_get "foo", "."
        foo.should eq @docs[:values].transform_keys(&:to_s)
      end
    end

    context "with path" do
      it "should be OK" do
        set = @rcl.json_set "test", ".", {}
        set.should eq "OK"
        set = @rcl.json_set "test", Rejson::Path.new(".foo"), "baz"
        set.should eq "OK"
        set = @rcl.json_set "test", ".bar", "qux"
        set.should eq "OK"
        get = @rcl.json_get "test"
        get.should == { "bar" => "qux", "foo" => "baz" }
      end
    end

    context "with flags" do
      before(:each) do
        set = @rcl.json_set "test", ".", foo: "bar"
        set.should eq "OK"
      end
      it "should allow nx/xx flags" do
        set = @rcl.json_set "test", "foo", "baz", nx: true
        set.should_not eq "OK"
        set = @rcl.json_set "test", "bar", "baz", xx: true
        set.should_not eq "OK"
        set = @rcl.json_set "test", "foo", "bam", xx: true
        set.should eq "OK"
        set = @rcl.json_set "test", "bar", "baz", nx: true
        set.should eq "OK"

        expect do
          @rcl.json_set "test", "foo", "baz", nx: true, xx: true
        end.to(raise_error ArgumentError)
        get = @rcl.json_get "test", "foo"
        get.should_not eq "baz"
      end
    end

    context "deep nested" do
      it "should get correct type" do
        set = @rcl.json_set "foo", Rejson::Path.root_path, @docs[:basic]
        set.should eq "OK"

        foo = @rcl.json_get "foo", ".arr"
        foo.should be_an_instance_of(Array)
        expect(foo.last.transform_keys(&:to_sym)).to(match({ 'subdict': true }))
      end
    end
  end

  context "delete" do
    before(:each) do
      @rcl.json_set "baz", Rejson::Path.root_path, { "name": "Pavan",
                                                     "lastSeen": 1_800 }
    end

    it "deletes a values" do
      foo = @rcl.json_del "baz", ".name"
      foo.should eq 1

      foo = @rcl.json_get "baz"
      foo.should include("lastSeen" => 1800)
      foo.should_not include("name" => "Pavan")
    end

    it "skips missing key" do
      foo = @rcl.json_del "missing", "."
      foo.should eq 0
    end
  end

  context "mget" do
    before(:each) do
      @rcl.json_set "foo", Rejson::Path.root_path, [1, 2, 3]
      @rcl.json_set "bar", Rejson::Path.root_path, { "name": "John Doe" }
      @rcl.json_set "baz", Rejson::Path.root_path, { "name": "Pavan",
                                                     "lastSeen": 1_800 }
    end

    it "fetches all values" do
      foo = @rcl.json_mget "bar", "baz", "."
      foo.should eq [{ "name" => "John Doe" }, { "lastSeen" => 1800, "name" => "Pavan" }]
    end

    it "fails due to missing argument" do
      expect do
        @rcl.json_mget "foo1"
      end.to(raise_error ArgumentError)
    end

    it "skips missing values" do
      foo = @rcl.json_mget "bar", "missing", "."
      foo.should eq [{ "name" => "John Doe" }, nil]
    end
  end

  context "type" do
    before(:each) do
      @rcl.json_set "foo", Rejson::Path.root_path, [1, 2, 3]
      @rcl.json_set "bar", Rejson::Path.root_path, { "name": "John Doe" }
      @rcl.json_set "baz", Rejson::Path.root_path, 1
    end

    it "gets object type" do
      type = @rcl.json_type "bar", "."
      type.should eq "object"
    end

    it "gets array type" do
      type = @rcl.json_type "foo", "."
      type.should eq "array"
    end

    it "gets integer type" do
      type = @rcl.json_type "baz", "."
      type.should eq "integer"
    end
  end

  context "number manipulation" do
    before(:each) do
      @rcl.json_set "test", ".", "foo" => 0, "bar" => 1
    end
    context "numicrby" do
      before(:each) do
        incr = @rcl.json_numincrby "test", ".foo", 1
        incr.should eq 1
      end

      it "should increment by 1" do
        get = @rcl.json_get "test"
        get.should == { "foo" => 1, "bar" => 1 }
      end
    end

    context "nummultby" do
      before(:each) do
        incr = @rcl.json_nummultby "test", ".bar", 2
        incr.should eq 2
      end

      it "should increment by 1" do
        get = @rcl.json_get "test"
        get.should == { "foo" => 0, "bar" => 2 }
      end
    end
  end

  context "test string manipulation" do
    before(:each) do
      @rcl.json_set "test", ".", "foo"
      @rcl.json_set "test2", ".", foo: "bar", baz: "zoo"
    end

    context "strappend" do
      it "append and return new length" do
        new_length = @rcl.json_strappend("test", "bar")
        new_length.should eq 6
        get = @rcl.json_get "test"
        get.should == "foobar"
      end
    end

    context "strlength" do
      it "return correct length" do
        length = @rcl.json_strlen("test")
        length.should be 3
      end
    end
  end

  context "test array manipulation" do
    before(:each) do
      @rcl.json_set "append", ".", @docs[:basic]
      @rcl.json_set "index", ".", "arr" => [0, 1, 2, 3, 2, 9, 0]
      @rcl.json_set "null", ".", "arr" => []
    end

    it "should append to array" do
      new_length = @rcl.json_arrappend "append", ".arr", 42
      new_length.should be 7
    end

    it "should return index of array" do
      element = @rcl.json_arrindex "index", ".arr", 3
      element.should eq 3
    end

    it "should insert element in array" do
      element = @rcl.json_arrinsert "index", ".arr", 2, "str"
      element.should eq 8
      get = @rcl.json_get "index"
      get.should == { "arr" => [0, 1, "str", 2, 3, 2, 9, 0] }
    end

    it "should get length of array" do
      length = @rcl.json_arrlen "index", ".arr"
      length.should eq 7
    end

    it "should pop element from array" do
      popped = @rcl.json_arrpop "index", ".arr", 5
      popped.should eq "9"
    end

    it "return null on popping null array" do
      expect do
        @rcl.json_arrpop "null", ".arr", 5
      end.to(raise_error Redis::CommandError)
    end

    it "should trim array" do
      trimmed = @rcl.json_arrtrim "index", ".arr", 1, -2
      trimmed.should eq 5
      trimmed_list = @rcl.json_get "index", ".arr"
      trimmed_list.should eq [1, 2, 3, 2, 9]
      trimmed = @rcl.json_arrtrim "index", ".arr", 0, 99
      trimmed.should eq 5
      trimmed = @rcl.json_arrtrim "index", ".arr", 0, 2
      trimmed_list = @rcl.json_get "index", ".arr"
      trimmed_list.should eq [1, 2, 3]
      trimmed.should eq 3
    end
  end

  context "test object manipulation" do
    before(:each) do
      @rcl.json_set "test", ".", @docs
    end
    context "objkeys" do
      before(:each) do
        @type_keys = @rcl.json_objkeys "test", ".types"
        @root_keys = @rcl.json_objkeys "test"
      end
      it "should should return keys" do
        @type_keys.should eq @docs[:types].keys.map(&:to_s)
        @root_keys.should eq @docs.keys.map(&:to_s)
      end
    end

    context "objlen" do
      before(:each) do
        @objlen = @rcl.json_objlen "test", ".types"
        @root_objlen = @rcl.json_objlen "test"
      end
      it "should return keys" do
        @objlen.should eq @docs[:types].keys.size
        @root_objlen.should eq @docs.keys.size
      end
    end
  end

  context "uncommon methods" do
    context "resp" do
      it "should return correct format" do
        @rcl.json_set "test", ".", nil
        resp = @rcl.json_resp "test"
        resp.should eq nil
        @rcl.json_set "test", ".", true
        resp = @rcl.json_resp "test"
        resp.should eq "true"
        @rcl.json_set "test", ".", 2.5
        resp = @rcl.json_resp "test"
        resp.should eq "2.5"
        @rcl.json_set "test", ".", 42
        resp = @rcl.json_resp "test"
        resp.should eq 42
        expect(@rcl.json_set("test", ".", [1, 2])).to be == "OK"
        resp = @rcl.json_resp "test"
        resp[0].should eq "["
        resp[1].should eq 1
        resp[2].should eq 2
      end
    end
  end

  context "workflows" do
    it "should set/get/delete" do
      obj = {
        'answer': 42,
        'arr': [nil, true, 3.14],
        'truth': {
          'coord': "out there"
        }
      }
      @rcl.json_set("obj", Rejson::Path.root_path, obj)

      get = @rcl.json_get("obj", Rejson::Path.new(".truth.coord"))
      get.should eq obj.dig(:truth).dig(:coord)

      del = @rcl.json_forget("obj", ".truth.coord")
      del.should eq 1

      get = @rcl.json_get("obj", Rejson::Path.new(".truth"))
      expect(get).to(match({}))
    end
  end
end
