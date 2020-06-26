# frozen_string_literal: true

require "redis"
require "json"

# Extends Redis class to add JSON functions
class Redis
  # rubocop:disable Metrics/AbcSize
  def json_set(key, path, data, options = {})
    pieces = [key, str_path(path), json_encode(data)]
    options[:nx] ||= false if options.dig(:nx)

    options[:xx] ||= false if options.dig(:xx)

    if options[:nx] && options[:xx]
      raise ArgumentError, "nx and xx are mutually exclusive: use one, the other or neither - but not both"
    elsif options[:nx]
      pieces.append("NX")
    elsif options[:xx]
      pieces.append("XX")
    end

    call_client(:set, pieces)
  end
  # rubocop:enable Metrics/AbcSize

  def json_get(key, *args)
    pieces = [key]

    if args.empty?
      pieces.append(str_path(Rejson::Path.root_path))
    else
      args.each do |arg|
        pieces.append(str_path(arg))
      end
    end

    begin
      json_decode call_client(:get, pieces)
    rescue TypeError
      nil
    end
  end

  def json_mget(key, *args)
    pieces = [key]

    raise ArgumentError, "Invalid arguments: Missing path" if args.empty?

    pieces.append(args)
    json_bulk_decode call_client(:mget, pieces)
  end

  def json_del(key, path = Rejson::Path.root_path)
    pieces = [key, str_path(path)]
    call_client(:del, pieces).to_i
  end

  alias json_forget json_del

  def json_type(key, path = Rejson::Path.root_path)
    pieces = [key, str_path(path)]
    call_client(:type, pieces).to_s
  end

  def json_numincrby(key, path, number)
    pieces = [key, str_path(path), number]
    call_client(:numincrby, pieces).to_i
  end

  def json_nummultby(key, path, number)
    pieces = [key, str_path(path), number]
    call_client(:nummultby, pieces).to_i
  end

  def json_strappend(key, string, path = Rejson::Path.root_path)
    pieces = [key, str_path(path), json_encode(string)]
    call_client(:strappend, pieces).to_i
  end

  def json_strlen(key, path = Rejson::Path.root_path)
    pieces = [key, str_path(path)]
    call_client(:strlen, pieces).to_i
  end

  def json_arrappend(key, path, json, *args)
    json_objs = [json_encode(json)]
    args.each { |arg| json_objs.append(json_encode(arg)) }
    pieces = [key, str_path(path), json_objs]
    call_client(:arrappend, pieces).to_i
  end

  def json_arrindex(key, path, scalar, start = 0, stop = 0)
    pieces = [key, str_path(path), scalar, start, stop]
    call_client(:arrindex, pieces).to_i
  end

  def json_arrinsert(key, path, index, *args)
    json_objs = []
    args.each { |arg| json_objs.append(json_encode(arg)) }
    pieces = [key, str_path(path), index, json_objs]
    call_client(:arrinsert, pieces).to_i
  end

  def json_arrlen(key, path = Rejson::Path.root_path)
    pieces = [key, str_path(path)]
    call_client(:arrlen, pieces).to_i
  end

  def json_arrpop(key, path = Rejson::Path.root_path, index = -1)
    pieces = [key, str_path(path), index]
    call_client(:arrpop, pieces).to_s
  end

  def json_arrtrim(key, path, start, stop)
    pieces = [key, str_path(path), start, stop]
    call_client(:arrtrim, pieces).to_i
  end

  def json_objkeys(key, path = Rejson::Path.root_path)
    pieces = [key, str_path(path)]
    call_client(:objkeys, pieces).to_a
  end

  def json_objlen(key, path = Rejson::Path.root_path)
    pieces = [key, str_path(path)]
    call_client(:objlen, pieces).to_i
  end

  def json_resp(key, path = Rejson::Path.root_path)
    pieces = [key, str_path(path)]
    call_client(:resp, pieces)
  end

  private

  def str_path(path)
    if path.instance_of?(Rejson::Path)
      path.str_path
    else
      path
    end
  end

  def json_encode(obj)
    JSON.generate(obj)
  end

  def json_decode(obj)
    JSON.parse(obj)
  end

  def json_bulk_decode(obj)
    res = []
    obj.to_a.each do |o|
      if o.nil?
        res.append(nil)
      else
        res.append(JSON.parse(o))
      end
    end
    res
  end

  def call_client(cmd, pieces)
    pieces.prepend("JSON.#{cmd.upcase}").join(" ")
    @client.call pieces
  end
end
