#Test 5x5 puzzle input string
#5 2/ 0 1 | 12* 2 7 | 4- 3 8 | 2- 4 9 | 12+ 5 10 15 | 10* 6 11 16 | 3+ 12 17 | 2. 13 | 11+ 14 19 24 | 12+ 18 22 23 | 2- 20 21

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
    
  	def initialize(line)
  	  unless (Regexp.new(CagePattern) =~ line) == 0
  	    raise Invalid, "#{line} is not a valid Cage specifier"
  	  end 
  	  
  	  @operation = $~[:operation]
  	  @target = $~[:target].to_i
  	  @indices = $~[:indices].split(" ").map{|s| s.to_i}	  
  	end
  	
  	#Pass in an array of positive integers
  	#Attempts to reach the target by applying the operation to the values over all orderings
  	def is_solved?(values)
  	  return false unless values.size == indices.size
  	  
  	  if @operation == "."
  	    values[0] == @target
  	  else
  	    Math.calc_all_perms(@operation, values).include?(@target)
  	  end
  	end
  	
  	def is_connected?(grid_side_length)
  	  return true if @indices.size == 1
  	   	  
  	  @indices.each do |index|
  	    candidates = []
  	    #Is the cell on the top edge of the grid?
  	    candidates << index - grid_side_length if index/grid_side_length > 0
  	    #Bottom edge?
  	    candidates << index + grid_side_length if index/grid_side_length < grid_side_length
  	    #Left edge? 
  	    candidates << index - 1 if index % grid_side_length != 0
  	    #Right edge?
  	    candidates << index + 1 if (index + 1) % grid_side_length != 0
  	    
  	    return false if (@indices & candidates).size == 0
	    end
	    #If we get here, the cage is connected
	    true
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
        @cages << Cage.new($~.to_s)
        cageRegExp =~ $~.post_match
      end
        
      #Check that every index from 0 to @grid_size - 1 is covered by exactly one cage
      coveredIndices = []
      @cages.each do |cage|
        coveredIndices.concat(cage.indices)
      end
      
      gridIndices = (0..@grid_size-1).to_a
      
      unless coveredIndices.sort == gridIndices
        raise Invalid, "The indexes #{coveredIndices} covered by the cages does not match #{gridIndices}" 
      end
      
      #Finally check that all cages are connected
      @cages.each do |cage|
        unless cage.is_connected?(@grid_side_length)
          raise Invalid, "The cage #{cage} is not connected in a grid of size #{@grid_side_length}"
        end
      end
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
          cage = cage_at(row, col)
          yield row, col, cage
        end
      end
    end
    
    private
    
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
    
    def is_cage_solved?(cage)
      cage.is_solved?(cage_digits(cage))
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
          eval "result #{operation}= operand"
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
    def solution_set(target, operation, number_of_unknowns, max, min=1)
      possible_values = (min..max).to_a
      solution_sets = []
      possible_values.combination(number_of_unknowns) do |combination|
        solution_sets << combination if calc_all_perms(operation, combination).include?(target)
      end
      solution_sets
    end
  end
end