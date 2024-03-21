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

    @object = {'store': {
      'book': [ 
        { 'category': 'reference',
          'author': 'Nigel Rees',
          'title': 'Sayings of the Century',
          'price': 8.95
        },
        { 'category': 'fiction',
          'author': 'Evelyn Waugh',
          'title': 'Sword of Honour',
          'price': 12.99
        },
        { 'category': 'fiction',
          'author': 'Herman Melville',
          'title': 'Moby Dick',
          'isbn': '0-553-21311-3',
          'price': 8.99
        },
        { 'category': 'fiction',
          'author': 'J. R. R. Tolkien',
          'title': 'The Lord of the Rings',
          'isbn': '0-395-19395-8',
          'price': 22.99
        }
      ],
      'bicycle': {
        'color': 'red',
        'price': 19.95
      }
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

    context "with json path" do
      it "should be OK" do
        set = @rcl.json_set "test", "$", {}
        set.should eq "OK"
        set = @rcl.json_set "test", Rejson::Path.new("$.foo"), "baz"
        set.should eq "OK"
        set = @rcl.json_set "test", "$.bar", "qux"
        set.should eq "OK"
        get = @rcl.json_get "test"
        get.should == { "bar" => "qux", "foo" => "baz" }
      end
    end

    context "with json path bracket notation" do
      it "should be OK" do
        set = @rcl.json_set "test", "$", {}
        set.should eq "OK"
        set = @rcl.json_set "test", Rejson::Path.new("$['foo']"), "baz"
        set.should eq "OK"
        set = @rcl.json_set "test", "$.bar", "qux"
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

    context "deep nested json path" do
      it "should get correct type" do
        set = @rcl.json_set "foo", Rejson::Path.json_root_path, @docs[:basic]
        set.should eq "OK"

        foo = @rcl.json_get "foo", "$.arr"
        foo.should be_an_instance_of(Array)
        foo.should eq [[42, nil, -1.2, false, ["sub", "array"], {"subdict"=>true}]]
      end
    end

  context "deep nested json path bracket notation" do
    it "should get correct type" do
      set = @rcl.json_set "foo", Rejson::Path.json_root_path, @docs[:basic]
      set.should eq "OK"

      foo = @rcl.json_get "foo", "$['arr']"
      foo.should be_an_instance_of(Array)
      foo.should eq [[42, nil, -1.2, false, ["sub", "array"], {"subdict"=>true}]]
    end
  end
end

  context "delete from json path" do
    before(:each) do
      @rcl.json_set "baz", Rejson::Path.json_root_path, { "name": "Pavan",
                                                     "lastSeen": 1_800 }
    end

    it "deletes a values" do
      foo = @rcl.json_del "baz", "$.name"
      foo.should eq 1

      foo = @rcl.json_get "baz"
      foo.should include("lastSeen" => 1800)
      foo.should_not include("name" => "Pavan")
    end

    it "skips missing key" do
      foo = @rcl.json_del "missing", "$"
      foo.should eq 0
    end
  end

  context "delete from json path bracket notation" do
    before(:each) do
      @rcl.json_set "baz", Rejson::Path.json_root_path, { "name": "Pavan",
                                                     "lastSeen": 1_800 }
    end

    it "deletes a values" do
      foo = @rcl.json_del "baz", "$['name']"
      foo.should eq 1

      foo = @rcl.json_get "baz"
      foo.should include("lastSeen" => 1800)
      foo.should_not include("name" => "Pavan")
    end

    it "skips missing key" do
      foo = @rcl.json_del "missing", "$"
      foo.should eq 0
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

  context "mget with json_path" do
    before(:each) do
      @rcl.json_set "foo", Rejson::Path.json_root_path, [1, 2, 3]
      @rcl.json_set "bar", Rejson::Path.json_root_path, { "name": "John Doe" }
      @rcl.json_set "baz", Rejson::Path.json_root_path, { "name": "Pavan",
                                                     "lastSeen": 1_800 }
    end

    it "fetches all values" do
      foo = @rcl.json_mget "bar", "baz", "$"
      foo.should eq [[{ "name" => "John Doe" }], [{ "lastSeen" => 1800, "name" => "Pavan" }]]
    end

    it "fails due to missing argument" do
      expect do
        @rcl.json_mget "foo1"
      end.to(raise_error ArgumentError)
    end

    it "skips missing values" do
      foo = @rcl.json_mget "bar", "missing", "$"
      foo.should eq [[{ "name" => "John Doe" }], nil]
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

    it "fetch names in name" do
      name = @rcl.json_mget "bar", "baz", "$.name"
      name.should eq [["John Doe"], ["Pavan"]]
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

    it "skips missing values" do
      doo = @rcl.json_mget "bar", "missing", "$"
      doo.should eq [[{"name"=>"John Doe"}], nil]
    end
  end

  context "type" do
    before(:each) do
      @rcl.json_set "foo", Rejson::Path.root_path, [1, 2, 3]
      @rcl.json_set "bar", Rejson::Path.root_path, { "name": "John Doe" }
      @rcl.json_set "baz", Rejson::Path.root_path, 1
    end

    it "gets object type" do
      type = @rcl.json_type "bar","$.name"
      type.should eq ["string"]
    end

    it "gets array type" do
      type = @rcl.json_type "foo", "."
      type.should eq "array"
    end

    it "gets array type" do
      type = @rcl.json_type "foo", "$"
      type.should eq ["array"]
    end


    it "gets integer type" do
      type = @rcl.json_type "baz", "."
      type.should eq "integer"
    end
  end

  context "type with json_path" do
    before(:each) do
      @rcl.json_set "foo", Rejson::Path.json_root_path, [1, 2, 3]
      @rcl.json_set "bar", Rejson::Path.json_root_path, { "name": "John Doe" }
      @rcl.json_set "baz", Rejson::Path.json_root_path, 1
    end

    it "gets object type" do
      type = @rcl.json_type "bar", "$"
      type.should eq ["object"]
    end

    it "gets array type" do
      type = @rcl.json_type "foo", "$"
      type.should eq ["array"]
    end

    it "gets integer type" do
      type = @rcl.json_type "baz", "$"
      type.should eq ["integer"]
    end
  end

  context "number manipulation" do
    before(:each) do
      @rcl.json_set "test", ".", "foo" => 0, "bar" => 1
    end
    context "numicrby" do
      before(:each) do
        incr = @rcl.json_numincrby "test", "$..foo", 1
        incr.should eq "[1]"
      end

      it "should increment by 1" do
        get = @rcl.json_get "test"
        get.should == { "foo" => 1, "bar" => 1 }
      end
    end

    context "nummultby" do
      before(:each) do
        incr = @rcl.json_nummultby "test", "$.bar", 2
        incr.should eq "[2]"
      end

      it "should increment by 1" do
        get = @rcl.json_get "test"
        get.should == { "foo" => 0, "bar" => 2 }
      end
    end
  end

  context "test string manipulation with json_path" do
    before(:each) do
      @rcl.json_set "test", "$", "foo"
      @rcl.json_set "test2", "$", foo: "bar", baz: "zoo"
    end

    context "strappend with json_path" do
      it "append and return new length" do
        new_length = @rcl.json_strappend("test", "bar", "$")
        new_length.should eq [6]
        get = @rcl.json_get "test"
        get.should == "foobar"
      end
    end

    context "strlength" do
      it "return correct length" do
        length = @rcl.json_strlen("test", "$")
        length.should eq [3]
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
        new_length = @rcl.json_strappend("test", "bar", ".")
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

    it "should insert element in array with json_path" do
      element = @rcl.json_arrinsert "index", "$.arr", 2, "str"
      element.should eq [8]
      get = @rcl.json_get "index"
      get.should == { "arr" => [0, 1, "str", 2, 3, 2, 9, 0] }
    end

    it "should get length of array" do
      length = @rcl.json_arrlen "index", "$.arr"
      length.should eq [7]
    end

    it "should pop element from array" do
      popped = @rcl.json_arrpop "index", "$..arr", 5
      popped.should eq ["9"]
    end

    it "return null on popping null array" do
      expect do
        @rcl.json_arrpop "null", "$.arr", 20
        if(popped.should eq "null")
          raise_error Redis::CommandError
        end
      end
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

  context "test array manipulation using json_path" do
    before(:each) do
      @rcl.json_set "append", "$", @docs[:basic]
      @rcl.json_set "index", "$", "arr" => [0, 1, 2, 3, 2, 9, 0]
      @rcl.json_set "null", "$", "arr" => []
      @rcl.json_set "doc1", "$", '{"axx":1, "b": 2, "nested": {"axx": 3}, "c": null}'
      @rcl.json_set "doc2", "$", '{"axx":4, "b": 5, "nested": {"axx": 6}, "c": null}'


    end

    it "should append to array" do
      new_length = @rcl.json_arrappend "append", "$.arr", 42
      new_length.should eq [7]
    end

    it "should return index of array" do
      element = @rcl.json_arrindex "index", "$.arr", 2
      element.should eq [2]
    end

    it "should insert element in array" do
      element = @rcl.json_arrinsert "index", "$.arr", 2, "str"
      element.should eq [8]
      get = @rcl.json_get "index"
      get.should == { "arr" => [0, 1, "str", 2, 3, 2, 9, 0] }
    end

    it "should get length of array" do
      length = @rcl.json_arrlen "index", "$.arr"
      length.should eq [7]
    end

    it "should pop element from array" do
      popped = @rcl.json_arrpop "index", "$.arr", [3,5]
      popped.should eq ["3"]
    end

    it "return null on popping null array" do
      expect do
        @rcl.json_arrpop "null", "$.arr", 20
        if(popped.should eq "null")
          raise_error Redis::CommandError
        end
      end
    end
    
    it "should trim array" do
      trimmed = @rcl.json_arrtrim "index", "$.arr", 1, -2
      trimmed.should eq [5]
      trimmed_list = @rcl.json_get "index", "$.arr"
      trimmed_list.should eq [[1, 2, 3, 2, 9]]
      trimmed = @rcl.json_arrtrim "index", "$.arr", 0, 99
      trimmed.should eq [5]
      trimmed = @rcl.json_arrtrim "index", "$.arr", 0, 2
      trimmed_list = @rcl.json_get "index", "$.arr"
      trimmed_list.should eq [[1, 2, 3]]
      trimmed.should eq [3]
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
        if(popped.should eq "null")
          raise_error Redis::CommandError
        end
      end
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

  context "test object manipulation with json_path" do
    before(:each) do
      @rcl.json_set "test", "$", @docs
    end
    context "objkeys" do
      before(:each) do
        @type_keys = @rcl.json_objkeys "test", "$.types"
        @root_keys = @rcl.json_objkeys "test"
      end
      it "should should return keys" do
        @type_keys.should eq [["null", "boolean", "integer", "number", "string", "object", "array"]]
        @root_keys.should eq ["simple", "basic", "scalars", "values", "types"]
      end
    end

    context "objlen" do
      before(:each) do
        @objlen = @rcl.json_objlen "test", "$.types"
        @root_objlen = @rcl.json_objlen "test"
      end
      it "should return keys" do
        @objlen.should eq [7]
        @root_objlen.should eq @docs.keys.size
      end
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

  context "uncommon methods with json_path" do
    context "resp" do
      it "should return correct format" do
        @rcl.json_set "test", "$", nil
        resp = @rcl.json_resp "test"
        resp.should eq nil
        @rcl.json_set "test", "$", true
        resp = @rcl.json_resp "test"
        resp.should eq "true"
        @rcl.json_set "test", "$", 2.5
        resp = @rcl.json_resp "test"
        resp.should eq "2.5"
        @rcl.json_set "test", "$", 42
        resp = @rcl.json_resp "test"
        resp.should eq 42
        expect(@rcl.json_set("test", "$", [1, 2])).to be == "OK"
        resp = @rcl.json_resp "test"
        resp[0].should eq "["
        resp[1].should eq 1
        resp[2].should eq 2
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

  context "workflows with json_path" do
    it "should set/get/delete" do
      obj = {
        'answer': 42,
        'arr': [nil, true, 3.14],
        'truth': {
          'coord': "out there"
        }
      }
      @rcl.json_set("obj", Rejson::Path.json_root_path, obj)

      get = @rcl.json_get("obj", Rejson::Path.new("$.truth.coord"))
      get.should eq [obj.dig(:truth).dig(:coord)]

      del = @rcl.json_forget("obj", "$.truth.coord")
      del.should eq 1

      get = @rcl.json_get("obj", Rejson::Path.new("$.truth"))
      expect(get).to(match([{}]))
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

  context "complex json manipulation on object json" do
    before(:each) do
      @rcl.json_set "obj", Rejson::Path.json_root_path, @object
      @rcl.json_set "obj1", Rejson::Path.json_root_path, @object
      @rcl.json_set "obj1", "$..book[2]", { 'category': 'sci-fi',
      'author': 'Herman Melville',
      'title': 'Moby Dick',
      'isbn': '0-553-21311-3',
      'price': 8.99
    }
    end
    it "the third book" do
      get = @rcl.json_mget ["obj", "obj1"],"$..book[2]"
      get.should eq [[{"author"=>"Herman Melville", "category"=>"fiction", "isbn"=>"0-553-21311-3", "price"=>8.99, "title"=>"Moby Dick"}],[{"author"=>"Herman Melville", "category"=>"sci-fi", "isbn"=>"0-553-21311-3", "price"=>8.99, "title"=>"Moby Dick"}]]
    end
    it "the authors of all books in the store" do
      get = @rcl.json_get "obj", "$.store.book[*].author"
      get.should eq ["Nigel Rees", "Evelyn Waugh", "Herman Melville", "J. R. R. Tolkien"]
    end
    it "filter all books cheaper than 10" do
      get = @rcl.json_get "obj", "$..book[?(@.price<10)]"
      get.should eq [{"author"=>"Nigel Rees","category"=>"reference","price"=>8.95,"title"=>"Sayings of the Century"},{"author"=>"Herman Melville","category"=>"fiction","isbn"=>"0-553-21311-3","price"=>8.99,"title"=>"Moby Dick"}]
    end
    it "last book in the order" do
      get = @rcl.json_get "obj","$..book[0:2]"
      get.should eq [{"author"=>"Nigel Rees", "category"=>"reference", "price"=>8.95, "title"=>"Sayings of the Century"}, {"author"=>"Evelyn Waugh", "category"=>"fiction", "price"=>12.99, "title"=>"Sword of Honour"}]
    end
    it "delete first 2 books in order" do
      del = @rcl.json_del "obj", "$..book[0:2]"
      del.should eq 2
    end
    it "price incremented by 2" do
      num = @rcl.json_numincrby "obj", "$..book[*].price", "2"
      num.should eq "[10.95,14.99,10.99,24.99]"
    end
    it "price multiplied by 3" do
      num = @rcl.json_nummultby "obj", "$..book[*].price", "3"
      num.should eq "[26.849999999999998,38.97,26.97,68.97]"
    end
    it "string lenght of string" do
      str = @rcl.json_strlen "obj", "$..book[*].title"
      str.should eq [22, 15, 9, 21]
    end
    it "add a new book" do
      add = @rcl.json_arrappend "obj", "$..book", { "category": "autobiography",
      "author": "Nelson Mandela",
      "title": "Long Walk to Freedom",
      "price": 18.95
      }
      add.should eq [5]
    end
    it "add a new book" do
      add = @rcl.json_arrinsert "obj", "$..book", 4,{ "category": "autobiography",
      "author": "M.K Gandhi",
      "title": "My experiments with truth",
      "price": 18.95
      }
      get = @rcl.json_get "obj", "$..book[*].title"
      get.should eq ["Sayings of the Century", "Sword of Honour", "Moby Dick", "The Lord of the Rings", "My experiments with truth"]
      add.should eq [5]
    end
    it "remove a book" do
      rm = @rcl.json_arrpop "obj", "$..book[-1]"
      rm.should eq [nil]
      get = @rcl.json_get "obj", "$..book[*].title"
      get.should eq ["Sayings of the Century", "Sword of Honour", "Moby Dick", "The Lord of the Rings"]
    end
    it "trim the array" do
      trim = @rcl.json_arrtrim "obj", "$..book", 0, 2
      trim.should eq [3]
      get = @rcl.json_get "obj", "$..book[*].title"
      get.should eq ["Sayings of the Century", "Sword of Honour", "Moby Dick"]
    end
    it "return object keys" do
      objkey = @rcl.json_objkeys "obj", "$..book[*]"
      objkey.should eq [["category", "author", "title", "price"], ["category", "author", "title", "price"], ["category", "author", "title", "isbn", "price"], ["category", "author", "title", "isbn", "price"]]
    end
    it "return object-len" do
      objlen = @rcl.json_objlen "obj", "$..book[*]"
      objlen.should eq [4, 4, 5, 5]
    end
    it "object type" do
      type = @rcl.json_type "obj", "$.store.book[*]"
      type.should eq ["object", "object", "object", "object"]
    end
  end
end
