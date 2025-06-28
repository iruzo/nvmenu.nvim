local M = {}

function M.fuzzy_score(text, query)
  if query == "" then return { score = 1000, positions = {} } end
  
  local original_text = text
  text = text:lower()
  query = query:lower()
  
  local score = 0
  local positions = {}
  local text_idx = 1
  local query_idx = 1
  
  while query_idx <= #query and text_idx <= #text do
    if text:sub(text_idx, text_idx) == query:sub(query_idx, query_idx) then
      table.insert(positions, text_idx)
      query_idx = query_idx + 1
    end
    text_idx = text_idx + 1
  end
  
  if query_idx <= #query then
    return nil
  end
  
  -- Exact prefix matches get the highest scores
  if original_text:lower():sub(1, #query) == query then
    score = 10000 + (1000 - #query)
  else
    -- Base score: prioritize how much of the query is matched
    local match_ratio = #positions / #query
    score = match_ratio * 1000
    
    -- Reward consecutive matches heavily
    local consecutive_bonus = 0
    local max_consecutive = 1
    local current_consecutive = 1
    
    for i = 2, #positions do
      if positions[i] == positions[i-1] + 1 then
        current_consecutive = current_consecutive + 1
        max_consecutive = math.max(max_consecutive, current_consecutive)
      else
        current_consecutive = 1
      end
    end
    consecutive_bonus = (max_consecutive / #query) * 500
    score = score + consecutive_bonus
    
    -- Heavily reward word boundary matches
    local word_boundary_matches = 0
    for _, pos in ipairs(positions) do
      local char_before = pos > 1 and original_text:sub(pos-1, pos-1) or " "
      if char_before:match("[%s%p]") then
        word_boundary_matches = word_boundary_matches + 1
      end
    end
    local word_boundary_bonus = (word_boundary_matches / #positions) * 300
    score = score + word_boundary_bonus
    
    -- Check for complete word matches
    local words = {}
    for word in original_text:lower():gmatch("%S+") do
      table.insert(words, word)
    end
    
    for _, word in ipairs(words) do
      if word:find(query, 1, true) then -- exact substring match
        score = score + 200
        if word == query then -- exact word match
          score = score + 500
        end
      end
    end
    
    -- Small penalty for later first match (less important now)
    local first_pos = positions[1] or #text
    score = score - (first_pos * 0.1)
  end
  
  return { score = score, positions = positions }
end

function M.filter_and_sort(lines, query)
  if query == "" then
    return lines
  end
  
  local scored_lines = {}
  for i, line in ipairs(lines) do
    local result = M.fuzzy_score(line, query)
    if result then
      table.insert(scored_lines, {
        line = line,
        original_index = i,
        score = result.score,
        positions = result.positions
      })
    end
  end
  
  table.sort(scored_lines, function(a, b) return a.score > b.score end)
  
  local filtered = {}
  for _, item in ipairs(scored_lines) do
    table.insert(filtered, item.line)
  end
  
  return filtered
end

return M