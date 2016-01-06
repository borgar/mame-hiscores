-- hiscore.lua
-- by borgar@borgar.net, WTFPL license
-- 
-- This uses MAME's built-in Lua scripting to implment
-- high-score saving with hiscore.dat infom just as older
-- builds did in the past.
-- 
-- A fair warning: This does not (yet?) take game reset
-- into account, only loading. So resetting the game via 
-- MAME interface may overwrite your highscores.


hiscoredata_path = "$HOME/.mame/hiscore.dat";
hiscore_path = "$HOME/.mame/hi";


current_checksum = 0;
default_checksum = 0;

scores_have_been_read = false;
mem_check_passed = false;

positions = {};

mem = manager:machine().devices[":maincpu"].spaces["program"];


function parse_table ( dsting )
  local _table = {};
  for line in string.gmatch(dsting, '([^\n]+)') do
    ncpu, offs, len, chk_st, chk_ed = string.match(line, '^([^:]+):([^:]+):([^:]+):([^:]+):([^:]+)');
    _table[ #_table + 1 ] = {
      cpu = tonumber(ncpu, 16),
      addr = tonumber(offs, 16),
      size = tonumber(len, 16),
      c_start = tonumber(chk_st, 16),
      c_end = tonumber(chk_ed, 16),
    };
  end
  return _table;
end


function read_hiscore_dat ()
  file = io.open( hiscoredata_path:gsub('%$HOME',os.getenv('HOME')), "r" );
  if not file then
    file = io.open( "hiscore.dat", "r" );
  end
  rm_match = '^' .. _G.emu.romname() .. ':';
  cluster = "";
  current_is_match = false;
  if file then
    repeat
      line = file:read("*l");
      if line then
        -- remove comments
        line = line:gsub( '[ \t\r\n]*;.+$', '' );
        -- handle lines
        if string.find(line, '^[0-9]+:[0-9]') then -- data line
          if current_is_match then
            cluster = cluster .. "\n" .. line;
          end
        elseif string.find(line, rm_match) then --- match this game
          current_is_match = true;
        elseif string.find(line, '^[a-z0-9_]+:') then --- some game
          if current_is_match and string.len(cluster) > 0 then
            break; -- we're done
          end
        else --- empty line or garbage
          -- noop
        end
      end
    until not line;
  end
  file:close();
  return cluster;
end


function check_mem ( posdata, memory )
  if #posdata < 1 then
    return false;
  end
  for ri,row in ipairs(posdata) do
    -- must use maincpu
    if row["cpu"] ~= 0 then
      return false;
    end
    -- must pass mem check
    if row["c_start"] ~= memory:read_u8(row["addr"]) then
      return false;
    end
    if row["c_end"] ~= memory:read_u8(row["addr"]+row["size"]-1) then
      return false;
    end
  end
  return true;
end


function get_file_name ()
  p = hiscore_path:gsub('%$HOME',os.getenv('HOME')):gsub('/$','');
  r = p .. '/' .. emu.romname() .. ".hi";
  return r;
end


function write_scores ( posdata, memory )
  local output = io.open(get_file_name(), "wb");
  if not output then
    -- attempt to create the directory, and try again
    os.execute( "mkdir " .. get_file_name():gsub( '[^/]+$', '' ) );
    output = io.open(get_file_name(), "wb");
  end
  if output then
    for ri,row in ipairs(posdata) do
      t = {};
      for i=0,row["size"]-1 do
        t[i+1] = memory:read_u8(row["addr"] + i)
      end
      output:write(string.char(table.unpack(t)));
    end
    output:close();
  end
end


function read_scores ( posdata, memory )
  local input = io.open(get_file_name(), "rb");
  if input then
    for ri,row in ipairs(posdata) do
      local str = input:read(row["size"]);
      for i=0,row["size"]-1 do
        local b = str:sub(i+1,i+1):byte();
        memory:write_u8( row["addr"] + i, b );
      end
    end
    input:close();
    return true;
  end
  return false;
end


function check_scores ( posdata, memory )
  local r = 0;
  -- commonly the first entry will be for the entire table
  -- so it will only trigger a write once a player enters
  -- his/her name in.
  row = positions[1];
  for i=0,row["size"]-1 do
    r = r + memory:read_u8( row["addr"] + i );
  end
  return r;
end


function init ()
  if not _G.scores_have_been_read then
    if check_mem( _G.positions, _G.mem ) then
      _G.default_checksum = check_scores( _G.positions, _G.mem );
      if read_scores( _G.positions, _G.mem ) then
        print( "scores read", "OK" );
      else
        -- likely there simply isn't a .hi file around yet
        print( "scores read", "FAIL" );
      end
      _G.scores_have_been_read = true;
      _G.current_checksum = check_scores( _G.positions, _G.mem );
      _G.mem_check_passed = true;
    else
      -- memory check can fail while the game is still warming up
      -- TODO: only allow it to fail N many times
    end
  end
end


last_write_time = -10;
function tick ()
  -- set up scores if they have been
  init();
  -- only allow save check to run when 
  if _G.mem_check_passed then
    -- The reason for this complicated mess is that
    -- MAME does expose a hook for "exit". Once it does,
    -- this should obviously just be done when the emulator
    -- shuts down (or reboots).
    local checksum = check_scores( _G.positions, _G.mem );
    if checksum ~= _G.current_checksum and checksum ~= _G.default_checksum then
      -- 5 sec grace time so we don't clobber io and cause
      -- latency. This would be bad as it would only ever happen
      -- to players currently reaching a new highscore
      if emu.time() > _G.last_write_time + 5 then
        write_scores( _G.positions, _G.mem );
        _G.current_checksum = checksum;
        _G.last_write_time = emu.time();
        -- print( "SAVE SCORES EVENT!", _G.last_write_time );
      end
    end
  end
end


dat = read_hiscore_dat();
if dat then
  print( "found hiscore.dat entry for " .. emu.romname() );
  positions = parse_table( dat );
  emu.sethook( tick, "frame" );
end
