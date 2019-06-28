require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject

  def self.columns
    table = self.table_name
    @columns ||= DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{table}
      SQL
    @columns.first.map {|thing| thing.to_sym}
  end

  def self.finalize!
    columns.each do |column|
      define_method column do 
        attributes[column]
      end

      define_method column.to_s+"=" do |value|
        attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.to_s.tableize
  end

  def self.all
    table = self.table_name
    results = DBConnection.execute(<<-SQL)
      SELECT
        #{table}.*
      FROM
        #{table}
      SQL
    parse_all(results)
  end

  def self.parse_all(results)
    results.map {|ele| new(ele)}
  end

  def self.find(id)
    table = self.table_name
    result = DBConnection.execute(<<-SQL, id)
      SELECT
        #{table}.*
      FROM
        #{table}
      WHERE
        id = ?
      LIMIT
        1
      SQL
    return nil if result.first.nil?
    new(result.first)
  end

  def initialize(params = {})
    params.each do |param, value|
      param = param.to_sym
      raise "unknown attribute '#{param}'" unless self.class.columns.include?(param)
      self.send( "#{param}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    # debugger
    values = self.class.columns.map do |column|
      send(column)
    end
    # debugger
    values
  end

  def insert
    table = self.class.table_name
    col_names = self.class.columns.join(',')

    question_marks = (["?"] * self.class.columns.count).join(",")
    values = attribute_values
    # debugger
    values[0] = id
    DBConnection.execute(<<-SQL, *values)
      INSERT INTO
        #{table} (#{col_names})
      VALUES
        (#{question_marks})
    SQL
    self.id = DBConnection.last_insert_row_id

  end

  def update
    table = self.class.table_name
    values = attribute_values
    values.shift
    set_columns = (self.class.columns.map {|column| column.to_s + " = ?"})[1..-1].join(", ")
    values << self.id
    DBConnection.execute(<<-SQL, *values)
      UPDATE
        #{table}
      SET
        #{set_columns}
      WHERE
        id = ?
    SQL
  end

  def save
    if self.id.nil?
      self.insert
    else
      self.update
    end
  end
end
