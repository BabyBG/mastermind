require 'io/console'

############################
## Board & Player classes ##
############################
# stores a 12x4 array containing all response pegs and ability to represent this in console with .show_board
class GameBoard
  attr_accessor :rows
  def initialize
    @rows = Array.new(12, [".", ".", ".", "."])
  end

  # show_board prints board to console 
  def show_board
    system 'clear'
    puts
    rows.each do |row|
      if row.class == Hash
        match_loc = row.values.join.count("b")
        match_num = row.values.join.count("w")
        print "\t"
        print "#{row.keys.join("\t")} \t #{match_loc} in correct position, #{match_num} in wrong position"
        puts
      else print "\t"
        print row.join("\t")
        puts
      end
    end
  end
end

# stores P1/P2, Human/CPU, and score
class Player
  attr_reader :human, :name
  attr_accessor :score
  def initialize(name)
    @name = name
    @human = gets.chomp
    @human == "" ? @human = true : @human = false
    @score = 0
  end
end

###########################################################
## Master function, assigns players to codemaker & breaker. 
## Chooses to play_round or play_again depending on context.
###########################################################
def master_sequence
  
  # pick human or cpu players, set codemaker & codebreaker
  introductory_text()
  p1 = Player.new("Player 1")
  puts "Press enter for Player 2 to be human. Type anything & enter to make Player 2 CPU."
  p2 = Player.new("Player 2")
  codemaker = p1
  codebreaker = p2
  play_round(codemaker, codebreaker, p1, p2)
  def play_again(codemaker, codebreaker, p1, p2)
    
    # switch roles and repeat play_round
    if codemaker == p1
      codemaker = p2
      codebreaker = p1
      play_round(codemaker, codebreaker, p1, p2)
    end
    
    # play again or end program?
    if codemaker == p2
      display_scores(p1, p2)
      one_more = gets.chomp  
      if one_more != ""
        codemaker = p1
        codebreaker = p2
        play_round(codemaker, codebreaker, p1, p2)
        play_again(codemaker, codebreaker, p1, p2)
      end
    end
  end
  play_again(codemaker, codebreaker, p1, p2)
  puts "Leaving mastermind.rb"
end

######################################################################
##  Methods for: 
## - making the 4 digit code 
## - getting a guess from a human, or an initial guess from CPU of 'xxyy'
## - comparing a guess to the code##
######################################################################
def make_hidden_code(codemaker)
  def ask_code()
    puts "Choose four numbers from 1-7 to create your secret code"
    num = STDIN.noecho(&:gets).chomp.split(//).map(&:to_i)
    num.length == 4 && num.all? {|d| d.between?(1, 7)} ? num : num = ask_code()
  end
  if codemaker.human == true
    puts
    puts "#{codemaker.name}, you are the codemaker."
    h_pegs = ask_code()
  else @r = Random.new
    puts
    puts "CPU has made a secret code, good luck!"
    h_pegs = [@r.rand(1..7), @r.rand(1..7), @r.rand(1..7), @r.rand(1..7)]
  end
  return h_pegs
end

def get_guess(codebreaker)
  print "\n"
  puts "#{codebreaker.name}, enter your guess by typing four numbers from 1-7."
  f = gets.chomp.split(//).map(&:to_i)
  f.length == 4 && f.all? {|a| a.between?(1, 7)} ? f : f = get_guess(codebreaker)
end

def first_cpu_guess
  x = Random.new.rand(1..7)
  y = Random.new.rand(1..7)
  if y == 7 && x == 7
    x = Random.new.rand(1..6)
  end
  x += 1 if x == y
  return [x, x, y, y]
end

def guess_vs_code(guess, code)
  num_match = []
  match = []
  eval_guess = []
  code.each_with_index do |e, i|
    if e == guess[i]
      match.push(i)
      num_match.push(e)
      eval_guess.push("b")
    end
  end
  code.each_with_index do |e, i|
    if match.none?(i) && guess.include?(e) && num_match.count(e) < guess.count(e)
      match.push(i)
      num_match.push(e)
      eval_guess.push("w")
    end
  end
  return eval_guess
end

#####################################
## Methods for CPU to make guesses ##
#####################################

def cpu_guess(prev_guesses, combinations)
  a = [1, 2, 3, 4, 5, 6, 7]
  poss_num = Hash[a.map {|q| [q, 0]}] 
  poss_loc = {}
  last_key = prev_guesses.keys.last
  last_value = prev_guesses.values.last

  # remove impossible locations
  remove_loc(combinations, last_key) if last_value.count("b") == 0
  delete_combo(last_value, last_key, poss_num, combinations, poss_loc)

  # add weight to possible locations   
  increment_poss_loc(last_value.count("b"), last_key, poss_loc)
  
  # find likeliest numbers & number locations
  likely_numbers = find_likely(poss_num, last_value.count)
  likely_locations = find_likely(poss_loc, last_value.count("b"))

  # dont guess these numbers, or these numbers at specific locations for next cpu guess
  dont_guess_num = last_key - likely_numbers
  dont_guess_loc = [] 
  last_key.each_with_index {|e, i| likely_locations.each {|f| dont_guess_loc.push([e, i]) unless [e, i] == f}}

  # populate temp_combo by filtering 'combinations' with 'dont_guess_num' & 'dont_guess_loc'
  temp_combo = temp_remove_num(combinations, dont_guess_num)
  temp_remove_loc(combinations, dont_guess_loc, temp_combo)
  
  # add weights to temp_combo
  likely_numbers.each {|u| temp_combo.each {|k, v| temp_combo[k] += 1 if k.include?(u)}}
  likely_locations.each do |n|
    temp_combo.each do |k, v|
      k.each_with_index {|e, i| temp_combo[k] += 2 if e == n[0] && i == n[1]}
    end
  end
  
  # make a guess from temp_combo, based on the highest-weighted key
  guess = temp_combo.select {|k, v| v == temp_combo.values.max}.keys.sample
  
  return guess
end

# case statement counts match number, deletes impossible combinations array based on number of matches
def delete_combo(last_value, last_key, poss_num, combinations, poss_loc)
  case last_value.count
  when 1..3
    increment_poss_num(last_value.count, last_key, poss_num, combinations)
    combinations.delete_if {|k, v| k.sort == last_key.sort}
  # if 4 or no matches remove entirely from poss_num
  when 4
    combinations.delete_if {|k, v| k.sort != last_key.sort || k == last_key}
    ([1, 2, 3, 4, 5, 6, 7] - last_key).each do |s|
      poss_num.delete_if {|k, v| k == s}
      poss_loc.delete_if {|k, v| k[0] == s}
    end
  # no matches also remove entirely some poss_num
  else
    puts poss_loc
    last_key.each do |s| 
      combinations.delete_if {|k, v| k.include?(s)}
      poss_num.delete_if {|k, v| k == s}
      poss_loc.delete_if {|k, v| k[0] == s}
    end
  end
end

#########################################################################
## Methods to add/remove weight to specific combinations for CPU guessing
## add weights to possible locations for cpu guessing
def increment_poss_loc(count, last_key, poss_loc)
  count.times do
    last_key.each_with_index do |k, v| arr = [k, v]
      poss_loc[arr] == nil ? poss_loc[arr] = 1 : poss_loc[arr] += 1
    end
  end
end

# add or remove weight to possible numbers for cpu guessing
# & trim invalid combinations from the data we're using to add/remove weight
def increment_poss_num(count, last_key, poss_num, combinations)
  if count == 1
    last_key.uniq.each {|o| poss_num.each {|k,_| poss_num[k] += 1 if k == o}}
  else count.times do
    last_key.each {|o| poss_num.each {|k,_| poss_num[k] += 1 if k == o}}
    end
  end
  # delete impossible combinations for 1/2 matches
  if count == 1 || count == 2
    last_key.uniq.combination(count + 1).to_a.each do |e|
      while e.length < count + 1
        e.push(nil)
      end
      combinations.delete_if {|k, v| (e - k).empty?}
    end
  end
  # delete impossible combinations for 3 matches
  if count == 3
    arr = []
    threes = last_key.combination(3).to_a
    poss_num.keys.map {|e| [e]}.each do |l|
      arr.concat(threes.product(l).map(&:flatten))
    end
    arr = arr.map {|e| e.sort}.uniq
    a = [1, 2, 3, 4, 5, 6, 7]
    c = a.product(a.product(a.product(a))).map(&:flatten)
    c.delete_if {|e| arr.include?(e.sort)}
    combinations.delete_if {|k, v| c.include?(k)}
  end
end

####################################################################
## Methods to filter total combinations array and narrow CPU guess##
####################################################################
# evaluates the likeliest numbers & locations based on weight for cpu guessing
def find_likely(poss_num, count)
  likely = Hash.new
  max_values = poss_num.select {|k, v| v == poss_num.values.max} 
  if max_values.count > count
    arr = max_values.keys.sample(count)
    arr.each {|e| likely[e] = poss_num[e]}
  else
    likely = poss_num.sort_by {|k, v| v}.last(count).to_h
  end
  likely_arr = likely.keys
  return likely_arr
end

# filters 'combinations' by numbers for 'temp_combo'
def temp_remove_num(combinations, dont_guess_num)
  arr = combinations.select do |k, v|
    (k - dont_guess_num).length == k.length
  end
  arr.count == 0 ? combinations : arr
end

# filters 'combinations' by number location for 'temp_combo'
def temp_remove_loc(combinations, dont_guess_loc, temp_combo)
  combinations.each do |k, v|
    k.each_with_index do |e, i|
      dont_guess_loc.each {|n| temp_combo[k] = v if e == n[0] && i == n[1]}
    end
  end
  temp_combo.count == 0 ? combinations : temp_combo
end

# permanently remove combinations with impossible locations
def remove_loc(combinations, last_key)
  last_key.each_with_index do |e, i|
    combinations.delete_if {|k, v| k[i] == e}
  end      
end

##################################################
## Method to play one 12-guess round only
## Called twice per game so players can swap roles
##################################################

def play_round(codemaker, codebreaker, p1, p2)
  board = GameBoard.new
  hidden_code = make_hidden_code(codemaker)
  a = [1, 2, 3, 4, 5, 6, 7]
  combinations = Hash[a.product(a.product(a.product(a))).map(&:flatten).map {|b| [b, 0]}]
  
  #lists of previous guesses to pass to CPU guess and ###POSS LOC AND POSS NUM NOT NEEDED HERE???
  
  prev_guesses = {} 

  #create spoiler wall if both players are human to conceal the code
  system 'clear' if p1.human == true && p2.human == true
  guess_number = 1
  code_broken = false
  
  #then loop till 12 OR correct guess
  while (code_broken == false && guess_number <= 12) do

    #Get a guess from the codebreaker
    if codebreaker.human == true
      breaker_guess = get_guess(codebreaker)
    elsif prev_guesses == {}
      breaker_guess = first_cpu_guess()
    else  
      breaker_guess = cpu_guess(prev_guesses, combinations)
    end
    if codebreaker.human == true && prev_guesses.keys.include?(breaker_guess)
      puts "You have already made this guess"
      breaker_guess = get_guess(codebreaker)
    end

    #guess is compared to hidden_code and generates a key peg array in response.
    guess_val = guess_vs_code(breaker_guess, hidden_code)
    #add guess paired with key peg response to hash of previous guesses
    prev_guesses[breaker_guess] = guess_val
    #update game board rows & show previous guesses and matches
    board.rows[12 - guess_number] = {breaker_guess => guess_val}
    board.show_board
    #check if code has been broken. End loop & update scores if true
    if guess_val == ["b", "b", "b", "b"]
      code_broken = true
      puts "Congratulations #{codebreaker.name}"
      puts "You have broken the code #{hidden_code} in #{guess_number} guesses!"
      puts "Your opponent gains #{guess_number} points."
      codemaker.score += guess_number  
    else guess_number += 1
      if guess_number > 12
      puts "Out of guesses this round. The code was #{hidden_code}."
      puts "Awarding #{codemaker.name}, the codemaker, 13 points."
      codemaker.score += 13
      end
    end
  end
end

###################################################################
##Methods to output text for introduction screen, displaying scores
###################################################################
def introductory_text()
  puts "Welcome to Mastermind. If you need a refresher on the rules please visit https://en.wikipedia.org/wiki/Mastermind_(board_game)"
  puts "Human vs. Human, CPU vs. Human, and CPU vs. CPU are all accepted."
  puts "Player 1 will play as the codemaker first in each round."
  puts "Press enter for Player 1 to be human. Type anything & enter to make Player 1 CPU."
end

def display_scores(p1, p2)
  puts "At the end of this round the scores are:"
  puts "PLAYER 1 - #{p1.score} POINTS"
  puts "PLAYER 2 - #{p2.score} POINTS."
  puts
  puts
  puts "Type any character to play again, carrying over the players & scores. Leave blank to end program."
  puts "Press enter to confirm choice."
end

##call master_sequence and begin program
master_sequence