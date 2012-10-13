#Test 5x5 puzzle input strings
#5 2/ 0 1 | 12* 2 7 | 4- 3 8 | 2- 4 9 | 12+ 5 10 15 | 10* 6 11 16 | 3+ 12 17 | 2. 13 | 11+ 14 19 24 | 12+ 18 22 23 | 2- 20 21 |
# 5 24* 0 5 6 7 | 4- 1 2 | 10+ 3 8 9 | 4. 4 | 2- 10 11 | 10* 12 17 | 5+ 13 14 | 2- 15 20 | 2/ 16 21 | 2/ 18 23 | 15* 19 24 | 4. 22 |
require 'set'

module KenKen
	class Invalid < StandardError
	end
	
	#The KenKen::Cage class represents a region in the puzzle grid with
	#	  operation: one of '+', '-', '*', '/', '.' for addition, subtraction, multiplication, division, or none, respectively.
	# 	target: a positive integer to be obtained from the operation
	#	  indices: an array of grid position indices
	class Cage	
  	#Pass in a string of the form <target><operation> <index1> <index2> ... <indexN>
  	#Example: "3+ 1 2"
  	CagePattern = "(?<target>[1-9]\\d*)(?<operation>[\\+\\-\\*\\/\\.])(?<indices>( \\d*)+)(\\s\\|\\s*)".freeze
  	
    #Read-only properties
    def operation
      @operation
    end
    
    def target
      @target
    end
    
    def indices
      @indices
    end
    
    def grid_side_length=(val)
      @grid_side_length = val
    end
    
    #Pass in an array of values, computes the remaining allowed values to solve the cage
    def choices_for_values(values)
      key = values.to_set
      
      return @choices_hash[key] if @choices_hash[key] != nil
      
      if (@operation == ".")
        @choices_hash[key] = [@target]
      else
        new_targets = []
        if (values.size == 0)
          new_targets << @target
        else
          if Math.is_commutative?(@operation)
            sub_result = Math.calculate(@operation, values)
            new_targets << Math.calculate(Math.inverse_operation(@operation), [@target, sub_result])
          else
            sub_result = Math.calculate(Math.inverse_operation(@operation), values)
            new_targets << Math.calculate(Math.inverse_operation(@operation), [@target, sub_result])
            new_targets.concat(Math.calc_all_perms(@operation, [@target].concat(values)).select{|n| n > 0})
          end
          #puts "New targets: #{new_targets}"
        end

        valid_digits = []
        allow_dups = [number_of_rows, number_of_cols].min > 1
        number_of_unknowns = @indices.size - values.size

        new_targets.each do |t|
          solution_sets = Math.solution_set(t, @operation, number_of_unknowns, @grid_side_length, 1, allow_dups)
          valid_digits.concat(solution_sets.flatten)
        end
        
        @choices_hash[key] = valid_digits.uniq
      end
      @choices_hash[key]
    end
    
  	def initialize(line, side_length)
  	  unless (Regexp.new(CagePattern) =~ line) == 0
  	    raise Invalid, "#{line} is not a valid Cage specifier"
  	  end 
  	  
  	  @operation = $~[:operation]
  	  @target = $~[:target].to_i
  	  @indices = $~[:indices].split(" ").map{|s| s.to_i}
  	  @grid_side_length = side_length
  	  @choices_hash = {}
  	end
  	
  	def is_connected?
  	  return true if @indices.size == 1
  	   	  
  	  @indices.each do |index|
  	    candidates = []
  	    #Is the cell on the top edge of the grid?
  	    candidates << index - @grid_side_length if index/@grid_side_length > 0
  	    #Bottom edge?
  	    candidates << index + @grid_side_length if index/@grid_side_length < @grid_side_length
  	    #Left edge? 
  	    candidates << index - 1 if index % @grid_side_length != 0
  	    #Right edge?
  	    candidates << index + 1 if (index + 1) % @grid_side_length != 0
  	    
  	    return false if (@indices & candidates).size == 0
	    end
	    #If we get here, the cage is connected
	    true
  	end
  	
  	def number_of_rows
      @indices.map{|i| i/@grid_side_length}.uniq.size
  	end
  	
  	def number_of_cols
  	  @indices.map{|i| i % @grid_side_length}.uniq.size
  	end
  	
  	def to_s
  	  "#{@target}#{@operation} #{@indices.join(" ")}"
  	end
  end
  
  class Puzzle
    PuzzlePattern = "(?<grid_side_length>[1-9]\\d*) (?<cages>(#{Cage::CagePattern})+)".freeze
    
    def initialize(line)
      s = line.dup
      
      unless (Regexp.new(PuzzlePattern) =~ s) == 0
        raise Invalid, "#{s} is not a valid Puzzle specifier"
      end
      
      @grid_side_length = $~[:grid_side_length].to_i
      @grid_size = @grid_side_length**2
      #This array will hold the values at each index
      @grid = Array.new(@grid_size)
      
      @cages = []
      cageSpecifiers = $~[:cages]
      
      cageRegExp = Regexp.new(Cage::CagePattern)
      cageRegExp =~ cageSpecifiers
      
      while $~ do
        @cages << Cage.new($~.to_s, @grid_side_length)
        cageRegExp =~ $~.post_match
      end
        
      #Check that every index from 0 to @grid_size - 1 is covered by exactly one cage
      coveredIndices = []
      @cages.each do |cage|
        coveredIndices.concat(cage.indices)
      end
      
      coveredIndices.sort!
      
      gridIndices = (0..@grid_size-1).to_a
      
      unless coveredIndices == gridIndices
        raise Invalid, "The indexes #{gridIndices - coveredIndices} are not covered by the cages." 
      end
      
      #Finally check that all cages are connected
      @cages.each do |cage|
        unless cage.is_connected?
          raise Invalid, "The cage #{cage} is not connected in a grid of size #{@grid_side_length}"
        end
      end
    end
    
    def dup
      copy = super
      @grid = @grid.dup
      copy
    end
    
    def grid_side_length
      @grid_side_length
    end
    
    def all_digits
      (1..@grid_side_length).to_a
    end
    
    def [](row, col)
      @grid[row*@grid_side_length + col]
    end
    
    def []=(row, col, newValue)
      unless all_digits.include?(newValue)
        raise Invalid, "#{newValue} is an invalid cell value"
      end
      @grid[row*@grid_side_length + col] = newValue
    end
    
    def each_unknown
      0.upto(@grid_side_length - 1) do |row|
        0.upto(@grid_side_length - 1) do |col|
          next unless self[row,col] == nil
          yield row, col
        end
      end
    end
    
    def to_s
      (0..(@grid_side_length - 1)).map{|row| @grid[row*@grid_side_length, @grid_side_length].map{|cell| cell || 0}.join(" ")}.join("\n")
    end
    
    def available_digits(row, col)
      #puts "Checking cell (#{row}, #{col})"
      cage = cage_at(row, col)
      
      if (cage.operation == ".") 
        return [cage.target]
      end
      
      available = all_digits - row_digits(row) - col_digits(col)
      
      #Need to intersect these now with the allowed values inside the cage
      solved_digits = cage_digits(cage)
      
      (available & cage.choices_for_values(solved_digits)).uniq
    end
      
    def row_digits(row)
      @grid[row*@grid_side_length, @grid_side_length].compact
    end
    
    def col_digits(col)
      results = []
      col.step(@grid_size - 1, @grid_side_length) do |i|
        val = @grid[i]
        results << val if (val)
      end
      results
    end
    
    def cage_digits(cage)
      @grid.values_at(*(cage.indices)).compact
    end
    
    def cage_for_index(index)
      @cages.each do |cage|
        return cage if cage.indices.include?(index)
      end
    end
    
    def cage_at(row, col)
      cage_for_index(row*@grid_side_length + col)
    end
  end

  #
  #These Math extensions define addition, subtraction, multiplication, division on multiple operands
  class << Math
    ValidOps = ["+", "-", "*", "/"].freeze

    def calculate(operation, operands)
      return nil unless ValidOps.include?(operation)

      result = nil
      operands.each_with_index do |operand, index|
        if (index == 0)
          result = operand
        else
          eval "result #{operation}= operand"#"#{operation == "/" ? "*1.0" : ""}"
        end
      end
      result
    end

    def inverse_operation(operation)
      case operation
      when "+" then "-"
      when "-" then "+"
      when "*" then "/"
      when "/" then "*"
      else nil
      end
    end

    def is_commutative?(operation)
      operation == "+" || operation == "*"
    end

    def calc_all_perms(operation, operands)
      if !ValidOps.include?(operation)
        return nil
      end

      results = []
      #If the operator is addition or multiplication, we only need to calulate one ordering by commutativity
      if (is_commutative?(operation))
        results << calculate(operation, operands)
      #Otherwise the set of all computations can be obtained by noting the following
      #a1-a2-a3-...-an = a1 - (a2 + a3 + ... + an)
      # and similarly for division:
      #a1/a2/a3/.../an = a1 / (a2*a3*...*an)
      #Thus by commutativity of "+" and "*", we need only iterate through the elements, apply the opposite operation to the remainder of the elements
      # and then apply that result to the current iteration element using the specified operation
      else
        operands.each_with_index do |operand, index|
          rest = operands.values_at(0...index) + operands.values_at((index + 1)..-1)
          results << calculate(operation, [operand, calculate(inverse_operation(operation), rest)])
        end
      end
      results.uniq
    end
    
    #Brute force checks the various integral combinations
    def solution_set(target, operation, number_of_unknowns, max, min=1, duplicateOperands=false)
      range = (min..max).to_a
      possible_values = [].concat(range)
           
      if (number_of_unknowns == 1)
          return [[target] & possible_values]
      end
      
      if (duplicateOperands)
        (min + 1).upto(max) do |n|
          possible_values = possible_values.concat(range)
        end
      end
      
      solution_sets = []
      possible_values.combination(number_of_unknowns) do |combination|
        solution_sets << combination if calc_all_perms(operation, combination).include?(target)
      end
      solution_sets.uniq
    end
  end
  
  #An exception raised when no solution is possible
  class Impossible < StandardError
  end
  
  def KenKen.scan(puzzle)
    puzzle_unchanged = false
    
    until puzzle_unchanged
      puzzle_unchanged = true
      row_min, col_min, possibilities_min = nil
      min = puzzle.grid_side_length + 1
      
      puzzle.each_unknown do |row, col|
        possibilities = puzzle.available_digits(row, col)
        
        case possibilities.size
        when 0
          puts "?????????????????????????????????"
          puts "Impossible! No values for cell (#{row}, #{col})"
          puts "#{puzzle}"
          puts "?????????????????????????????????"
          raise Impossible
        when 1
          puzzle[row, col] = possibilities[0]
          puts "================================="
          puts "(#{row}, #{col}) is #{possibilities[0]}"
          puts "#{puzzle}"
          puts "================================="
          puzzle_unchanged = false
        else
          if puzzle_unchanged && possibilities.size < min
            min = possibilities.size
            row_min, col_min, possibilities_min = row, col, possibilities
          end
        end
      end
    end
    
    return row_min, col_min, possibilities_min
  end
  
  def KenKen.solve(puzzle)
    puzzle_copy = puzzle.dup
    
    row, col, possibilities = scan(puzzle_copy)
    
    if row == nil
      puts "SOLVED!"
      return puzzle_copy
    end
    
    possibilities.each do |possibility|
      puzzle_copy[row, col] = possibility      
      puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
      puts "Guessing #{possibility} in cell (#{row}, #{col})"
      puts "#{puzzle_copy}"
      puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^"
      
      begin
        return solve(puzzle_copy)
      rescue Impossible
        next
      end
    end
    
    raise Impossible
  end
end
