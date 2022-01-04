--- a parser for surrounding character pairs
-- @module parser
local utils = require "surround.utils"

local OPENING = 1
local CLOSING = 2
local LINE = 1
local COLUMN = 2

--- Find index of bracket
-- @param line The content of the current line.
-- @param line_no The line number in the buffer.
-- @param col_no The column number to look at.
-- @param pair The bracket pair to look for.
-- @param pair_stack The depth of the currently nested brackets.
-- @param requested_pair The leve of depth relative to nested pair that should be removed
-- @param nested Boolean value indicating whether to look for nested or non-nested brackets.
-- @param opening Boolean value indicating whether to look for the opening bracket. A false value will look for the closing bracket.
-- @return A table containing the values: error, index, remove_space, requested_pair, pair_stack
local function find_bracket_index(line, line_no, col_no, pair, pair_stack, requested_pair, nested, opening)

  local remove_space = false
  local index = nil

  local primary
  local opposite
  if opening then
    primary = OPENING
    opposite = CLOSING
  else
    primary = CLOSING
    opposite = OPENING
  end

  -- Get the character currently looping through and the previous one for escaping purposes
  local prev_char = line:sub(col_no - 1, col_no - 1)
  local next_char = line:sub(col_no + #pair[primary], col_no + #pair[primary])

  local curr_char = {}
  curr_char[primary] = line:sub(col_no, col_no + #pair[primary] - 1)
  curr_char[opposite] = line:sub(col_no, col_no + #pair[opposite] - 1)


  if nested then
    -- If found the opposite bracket, add it to the pair stack
    if (curr_char[opposite] == pair[opposite] and prev_char ~= "\\") then
      pair_stack = pair_stack + 1
    end
    if (curr_char[primary] == pair[primary] and prev_char ~= "\\") then
      -- if the pair stack is empty set the indexes
      if pair_stack <= 0 then
        if requested_pair == 0 then
          if primary == OPENING and next_char == " " then
            remove_space = true
          end
          if primary == CLOSING and prev_char == " " then
            remove_space = true
          end
          index = {line_no, col_no}
        end
        requested_pair = requested_pair - 1
      end
      pair_stack = pair_stack - 1
    end
  else
    if (curr_char[primary] == pair[primary] and prev_char ~= "\\") then
      if primary == OPENING and next_char == " " then
        remove_space = true
      end
      if primary == CLOSING and prev_char == " " then
        remove_space = true
      end
      index = {line_no, col_no}
    elseif (curr_char[opposite] == pair[opposite] and prev_char ~= "\\") then
      -- since items are non-nested, finding opposite bracket first is a show-stopper
      return true
    end
  end
  return {
    error = false,
    index = index,
    remove_space = remove_space,
    requested_pair = requested_pair,
    pair_stack = pair_stack
  }
end

local function get_pair_positions(buffer, cursor_position, surrounding_char, n, nested, func, includes)
  n = n or 0

  local temp_results_table = {}
  temp_results_table["requested_pair"] = n

  local pair = utils.get_char_pair(surrounding_char)

  local opening_index
  local closing_index
  local function_start_index
  local remove_space_after_opening
  local remove_space_before_closing

  local buffer_prev_indexes = {
    cursor_position[LINE], cursor_position[COLUMN] - 1
  }
  local buffer_next_indexes = {
    cursor_position[LINE], cursor_position[COLUMN] + 1
  }

  local char_before_cursor = buffer[cursor_position[LINE]]:sub(
    cursor_position[COLUMN] - 1,
    cursor_position[COLUMN] - 1
  )
  local char_at_cursor = buffer[cursor_position[LINE]]:sub(
    cursor_position[COLUMN],
    cursor_position[COLUMN]
  )

  if (pair[OPENING] == char_at_cursor and char_before_cursor ~= "\\") then
    opening_index = {cursor_position[LINE], cursor_position[COLUMN]}
  elseif (pair[CLOSING] == char_at_cursor and char_before_cursor ~= "\\") then
    closing_index = {cursor_position[LINE], cursor_position[COLUMN]}
  end

  -- Find opening character indexes
  -- Initialize pair stack
  temp_results_table["pair_stack"] = 0

  -- Loop through the lines before the cursor in reverse order
  for line_no = buffer_prev_indexes[LINE], 1, -1 do
    -- Check if already found
    if opening_index then break end
    local line = buffer[line_no]
    if line_no < buffer_prev_indexes[LINE] then
      -- Loop through the line in reverse order if cursor is not on the line
      for col_no = #line, 1, -1 do
        temp_results_table = find_bracket_index(line, line_no, col_no, pair, temp_results_table["pair_stack"], temp_results_table["requested_pair"], nested, true)
        if temp_results_table["error"] then
          return nil
        end
        if temp_results_table["index"] then
          opening_index = temp_results_table["index"]
          remove_space_after_opening = temp_results_table["remove_space"]
          break
        end
      end
    else
      -- Loop through the line in reverse order from the cursor position if cursor is on the line
      for col_no = buffer_prev_indexes[COLUMN], 1, -1 do
        temp_results_table = find_bracket_index(line, line_no, col_no, pair, temp_results_table["pair_stack"], temp_results_table["requested_pair"], nested, true)
        if temp_results_table["error"] then
          return nil
        end
        if temp_results_table["index"] then
          opening_index = temp_results_table["index"]
          remove_space_after_opening = temp_results_table["remove_space"]
          break
        end
      end
    end
  end

  temp_results_table["requested_pair"] = n
  -- Find closing character indexes
  -- Initialize pair stack
  temp_results_table["pair_stack"] = 0
  -- Loop through the buffer line starting with the line the cursor is on
  for line_no = buffer_next_indexes[LINE], #buffer do
    -- If not already found find the closing pair
    if closing_index then break end
    local line = buffer[line_no]
    if line_no > buffer_next_indexes[LINE] then
      -- Loop through the characters in the line from the start if cursor is not on the line
      for col_no = 1, #line do
        temp_results_table = find_bracket_index(line, line_no, col_no, pair, temp_results_table["pair_stack"], temp_results_table["requested_pair"], nested, false)
        if temp_results_table["error"] then
          return nil
        end
        if temp_results_table["index"] then
          closing_index = temp_results_table["index"]
          remove_space_before_closing = temp_results_table["remove_space"]
          break
        end
      end
    else
      -- Loop through the characters in the line from the cursor position if cursor is on the line
      for col_no = buffer_next_indexes[COLUMN], #line do
        temp_results_table = find_bracket_index(line, line_no, col_no, pair, temp_results_table["pair_stack"], temp_results_table["requested_pair"], nested, false)
        if temp_results_table["error"] then
          return nil
        end
        if temp_results_table["index"] then
          closing_index = temp_results_table["index"]
          remove_space_before_closing = temp_results_table["remove_space"]
          break
        end
      end
    end
  end

  if func then
    -- Find the start of the function name.
    for col_no = opening_index[COLUMN] - 1, 1, -1 do
      local current_char = buffer[opening_index[LINE]]:sub(col_no, col_no)
      if not string.isalnum(current_char, includes) then
        function_start_index = {opening_index[LINE], col_no + 1}
        break
      end
    end
  end

  if (opening_index and closing_index) then
    return {opening_index, closing_index, function_start_index, remove_space_after_opening, remove_space_before_closing}
  else
    return nil
  end
end

--- Find the surrounding pair.
-- Returns the indexes of the nearest surrounding pair char in the given buffer relative to the give cursor position.
-- @param buffer the buffer to look for the surrounding pair char
-- @param cur_pos the cursor positon in the buffer (1 indexed)
-- @param char the char for which the surrounding pair must be found
-- @return a table consisting of a pair of indexes (1 indexed) in the form {opening_char_index, closing_char_index} or false if no pairs found
-- @function get_surround_pair
local function get_surround_pair(buffer, cursor_position, surrounding_char,
                                 includes, n)
  local surround_pairs = vim.g.surround_pairs
  -- If the character is not in the pairs table return an emoty string.
  local all_pairs = vim.tbl_flatten(table.merge(surround_pairs.nestable,
                                                surround_pairs.linear))
  local special_char = {"f"}
  for _, char in ipairs(special_char) do
    table.insert(all_pairs, #all_pairs + 1, char)
  end
  if not table.contains(all_pairs, surrounding_char) then return nil end

  if (surrounding_char == "f") then
    return get_pair_positions(buffer, cursor_position, "(", n, true, true, includes)
  end
  -- Check if the character can be nested.
  local is_nestable = false
  for _, pair in pairs(surround_pairs.nestable) do
    if table.contains(pair, surrounding_char) then is_nestable = true end
  end

  if (is_nestable) then
    return get_pair_positions(buffer, cursor_position, surrounding_char, n, true)
  else
    return get_pair_positions(buffer, cursor_position, surrounding_char, nil, false)
  end
end

return {get_surround_pair = get_surround_pair}
