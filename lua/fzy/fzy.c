#include "choices.h"
#include "match.h"

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>

#define CHOICES_META "choices_metatable"

typedef struct {
  // Choices struct
  choices_t choices;

  // Reference to table the stores references to the strings used by the choices object
  int ref;
} choices_ud_t;

static choices_ud_t * fzy_choices_check(lua_State *L, int index)
{
  return (choices_ud_t *)luaL_checkudata(L, index, CHOICES_META);
}

static int fzy_choices_gc(lua_State *L)
{
  choices_ud_t * tofree = fzy_choices_check(L, -1);
  choices_destroy(&tofree->choices);

  // Remove reference to reference table
  luaL_unref(L, LUA_REGISTRYINDEX, tofree->ref);
  return 0;
}

// Creates a new choices object
//
// Upon creation, also create the reference table.
static int fzy_choices_create(lua_State *L)
{
  choices_ud_t * new = (choices_ud_t *)lua_newuserdata(L, sizeof(choices_ud_t));
  // TODO(vigoux): Make the number of workers configurable ?
  choices_init(&new->choices, 0);

  // Add the metatable to the stack
  luaL_getmetatable(L, CHOICES_META);

  // Set the metatable on the userdata
  lua_setmetatable(L, -2);

  // Create the reference table
  lua_createtable(L, 1, 0);
  new->ref = luaL_ref(L, LUA_REGISTRYINDEX);
  return 1;
}

static int fzy_choices_populate(lua_State *L)
{
  choices_ud_t * c = fzy_choices_check(L, 1);
  luaL_checktype(L, 2, LUA_TTABLE);

  // Prepare the stack for addition to the reference table
  lua_rawgeti(L, LUA_REGISTRYINDEX, c->ref); // [reftbl]

  // Now iterate over the table and add to the choices
  size_t nelems = lua_objlen(L, 2);
  for (size_t i = 0; i < nelems; i++) {
    lua_rawgeti(L, 2, i + 1); // [reftbl, elem]

    const char * choice = luaL_checkstring(L, -1);
    choices_add(&c->choices, choice);
    luaL_ref(L, -2); // [reftbl]
  }
  lua_pop(L, 1);

  return 0;
}

static int fzy_choices_available(lua_State *L)
{
  choices_ud_t * c = fzy_choices_check(L, 1);

  lua_pushinteger(L, choices_available(&c->choices));
  return 1;
}

static int fzy_choices_search(lua_State *L)
{
  choices_ud_t * c = fzy_choices_check(L, 1);
  const char * needle = luaL_checkstring(L, 2);

  choices_search(&c->choices, needle);

  // Now create the result table
  lua_createtable(L, choices_available(&c->choices), 0); // [ret]
  for (size_t i = 0; i < choices_available(&c->choices); i++) {
    lua_createtable(L, 2, 0); // [ret, elem]
                              //
    lua_pushstring(L, choices_get(&c->choices, i)); // [ret, elem, str]
    lua_rawseti(L, -2, 1); // [ret, elem]

    lua_pushnumber(L, choices_getscore(&c->choices, i)); // [ret, elem, score]
    lua_rawseti(L, -2, 2); // [ret, elem]

    lua_rawseti(L, -2, i+1); // [ret]
  }
  return 1;
}

static int push_item(lua_State *L, choices_t *c, size_t index)
{
  const char * item = choices_get(c, index);
  if (item) {
    lua_pushstring(L, item);
    lua_pushinteger(L, c->selection + 1);
  } else {
    lua_pushnil(L);
    lua_pushnil(L);
  }
  return 2;
}

static int push_selected(lua_State *L, choices_t *c)
{
  return push_item(L, c, c->selection);
}

static int fzy_choices_selected(lua_State *L)
{
  choices_ud_t * c = fzy_choices_check(L, 1);

  return push_selected(L, &c->choices);
}

static int fzy_choices_next(lua_State *L)
{
  choices_ud_t * c = fzy_choices_check(L, 1);
  choices_next(&c->choices);

  return push_selected(L, &c->choices);
}

static int fzy_choices_prev(lua_State *L)
{
  choices_ud_t * c = fzy_choices_check(L, 1);
  choices_prev(&c->choices);

  return push_selected(L, &c->choices);
}

static int fzy_choices_get(lua_State *L)
{
  choices_ud_t * c = fzy_choices_check(L, 1);
  int choice = luaL_checkint(L, 2);
  if (choice < 1) {
    return luaL_argerror(L, 2, "Expected a number greater than 1");
  }

  push_item(L, &c->choices, (size_t)(choice - 1)); // [elem, index]
  lua_pop(L, 1); // [elem]
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
  { "get", fzy_choices_get },
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
