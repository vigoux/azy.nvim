#include "choices.h"
#include "match.h"

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>

#define CHOICES_META "choices_metatable"

static choices_t * fzy_choices_check(lua_State *L, int index)
{
  return (choices_t *)luaL_checkudata(L, index, CHOICES_META);
}

static int fzy_choices_gc(lua_State *L)
{
  choices_t * tofree = fzy_choices_check(L, -1);
  choices_destroy(tofree);
  return 0;
}

static int fzy_choices_create(lua_State *L)
{
  choices_t * new = (choices_t *)lua_newuserdata(L, sizeof(choices_t));
  // TODO(vigoux): Make the number of workers configurable ?
  choices_init(new, 0);

  // Add the metatable to the stack
  luaL_getmetatable(L, CHOICES_META);

  // Set the metatable on the userdata
  lua_setmetatable(L, -2);
  return 1;
}

static int fzy_choices_populate(lua_State *L)
{
  choices_t * c = fzy_choices_check(L, 1);
  luaL_checktype(L, 2, LUA_TTABLE);

  // Now iterate over the table and add to the choices
  size_t nelems = lua_objlen(L, 2);
  for (size_t i = 0; i < nelems; i++) {
    lua_rawgeti(L, 2, i + 1); // [elem]

    // FIXME: there may be some problems here with the lifetime of the strings
    const char * choice = luaL_checkstring(L, -1);
    choices_add(c, choice);
    lua_pop(L, 1); // []
  }

  return 1;
}

static int fzy_choices_available(lua_State *L)
{
  choices_t * c = fzy_choices_check(L, 1);

  lua_pushinteger(L, choices_available(c));
  return 1;
}

static int fzy_choices_search(lua_State *L)
{
  choices_t * c = fzy_choices_check(L, 1);
  const char * needle = luaL_checkstring(L, 2);

  choices_search(c, needle);

  // Now create the result table
  lua_createtable(L, choices_available(c), 0); // [ret]
  for (size_t i = 0; i < choices_available(c); i++) {
    lua_createtable(L, 2, 0); // [ret, elem]
                              //
    lua_pushstring(L, choices_get(c, i)); // [ret, elem, str]
    lua_rawseti(L, -2, 1); // [ret, elem]

    lua_pushnumber(L, choices_getscore(c, i)); // [ret, elem, score]
    lua_rawseti(L, -2, 2); // [ret, elem]

    lua_rawseti(L, -2, i+1); // [ret]
  }
  return 1;
}

static void push_selected(lua_State *L, choices_t * c)
{
  if (c->available) {
    lua_pushstring(L, choices_get(c, c->selection));
  } else {
    lua_pushnil(L);
  }
}

static int fzy_choices_selected(lua_State *L)
{
  choices_t * c = fzy_choices_check(L, 1);

  push_selected(L, c);
  return 1;
}

static int fzy_choices_next(lua_State *L)
{
  choices_t * c = fzy_choices_check(L, 1);
  choices_next(c);

  push_selected(L, c);
  return 1;
}

static int fzy_choices_prev(lua_State *L)
{
  choices_t * c = fzy_choices_check(L, 1);
  choices_prev(c);

  push_selected(L, c);
  return 1;
}

static int fzy_match(lua_State *L)
{
  const char * needle = luaL_checkstring(L, 1);
  const char * haystack = luaL_checkstring(L, 2);
  const size_t n = strlen(needle);

  if (has_match(needle, haystack)) {
    size_t * positions = (size_t *)calloc(n, sizeof(size_t));

    lua_pushnumber(L, match_positions(needle, haystack, positions));

    lua_createtable(L, n, 0); // [score, positions]
    for (size_t i = 0; i < n; i++) {
      lua_pushinteger(L, positions[i] + 1); // [score, positions, pos]
      lua_rawseti(L, -2, i+1); // [score, positions]
    }

    free(positions);
  } else {
    lua_pushnil(L);
    lua_pushnil(L);
  }
  return 2;
}

static struct luaL_Reg choices_meta[] = {
  { "add", fzy_choices_populate },
  { "available", fzy_choices_available },
  { "search", fzy_choices_search },
  { "selected", fzy_choices_selected },
  { "next", fzy_choices_next },
  { "prev", fzy_choices_prev },
  { "__gc", fzy_choices_gc },
  { NULL, NULL }
};

static struct luaL_Reg public_interface[] = {
  { "create", fzy_choices_create },
  { "match", fzy_match },
  { NULL, NULL }
};

int luaopen_fzy(lua_State *L)
{
  // Create choices metatable
  if (luaL_newmetatable(L, CHOICES_META)) {
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, choices_meta, 0);
  }

  // Create public interface
  luaL_newlib(L, public_interface);

  return 1;
}
