require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    return @columns if @columns

    array = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{table_name}
    SQL

    array = array.first.map {|col| col.to_sym}
    @columns = array
  end

  def self.finalize!
    columns.each do |col|
      define_method(col) { attributes[col] }
      define_method("#{col}=") do |value|
        attributes[col] = value
      end
    end
  end

  def self.table_name=(table_name)
    table_name = table_name
  end

  def self.table_name
    self.to_s.downcase + 's'
  end

  def self.all
    array = DBConnection.execute(<<-SQL)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
    SQL
    parse_all(array)
  end

  def self.parse_all(results)
    results.map do |result|
      self.new(result)
    end
  end

  def self.find(id)
    item = DBConnection.execute(<<-SQL, id)
      SELECT
        #{table_name}.*
      FROM
        #{table_name}
      WHERE
        #{table_name}.id = ?
      LIMIT
        1
    SQL
    parse_all(item).first
  end

  def initialize(params = {})
    params.each do |k, v|
      k = k.to_sym
      if !self.class.columns.include?(k)
        raise "unknown attribute '#{k}'"
      else
        self.send("#{k}=", v)
      end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |col| self.send(col) }
  end

  def insert
    columns = self.class.columns.drop(1)
    col_names = columns.map(&:to_s).join(", ")
    question_marks = (["?"] * columns.length).join(", ")
    DBConnection.execute(<<-SQL, *attribute_values[1..-1])
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{question_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_names = self.class.columns.map do |i|
      "#{i} = ?"
    end.join(", ")

    DBConnection.execute(<<-SQL, *attribute_values, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{col_names}
      WHERE
        #{self.class.table_name}.id = ?
    SQL
  end

  def save
    if !id.nil?
      update
    else
      insert
    end
  end
end
