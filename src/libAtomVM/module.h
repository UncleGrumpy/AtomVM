/***************************************************************************
 *   Copyright 2017 by Davide Bettio <davide@uninstall.it>                 *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Lesser General Public License as        *
 *   published by the Free Software Foundation; either version 2 of the    *
 *   License, or (at your option) any later version.                       *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .        *
 ***************************************************************************/

/**
 * @file module.h
 * @brief Module loading functions
 *
 * @details This header defines all the module loading functions and the Module struct.
 */

#ifndef _MODULE_H_
#define _MODULE_H_

#include <stdint.h>

#include "atom.h"
#include "context.h"

typedef term (*BifImpl)();
typedef term (*BifImpl0)(Context *ctx);
typedef term (*BifImpl1)(Context *ctx, uint32_t failure_label, int live, term arg1);
typedef term (*BifImpl2)(Context *ctx, uint32_t failure_label, int live, term arg1, term arg2);

typedef struct
{
    char magic[4];
    uint32_t size;
    uint32_t info_size;
    uint32_t version;
    uint32_t opcode_max;
    uint32_t labels;
    uint32_t functions_count;

    uint8_t code[1];
} __attribute__((packed)) CodeChunk;

struct ExportedFunction;

union imported_func
{
    const struct ExportedFunction *func;
    BifImpl bif;
};

struct Module
{
    CodeChunk *code;
    void *export_table;
    void *atom_table;

    union imported_func *imported_funcs;
    void *local_labels;

    void **labels;

    void *literals_data;
    void const* *literals_table;

    int free_literals_data : 1;
};

#ifndef TYPEDEF_MODULE
#define TYPEDEF_MODULE
typedef struct Module Module;
#endif

/**
 * @briefs Gets exported function index by searching it by function name and arity
 *
 * @details Gets exported function index by searching it by function name and arity
 * @param this_module the module on which the function will be searched.
 * @param func_name function name atom string.
 * @param func_arity function arity.
 */
extern uint32_t module_search_exported_function(Module *this_module, AtomString func_name, int func_arity);

/***
 * @brief Destoys an existing Module
 *
 * @details Destorys a module and free Module resources.
 * @param module the module that will be freed.
 */
extern void module_destroy(Module *module);

/**
 * @brief Parse a BEAM file and returns a Module
 *
 * @details Parse a BEAM file a returns a newly allocated and initialized Module struct.
 * @param iff_binary the IFF file data.
 * @param size the size of the buffer containing the IFF data.
 */
extern Module *module_new_from_iff_binary(void *iff_binary, unsigned long size);

/**
 * @brief Gets a literal stored on the literal table of the specified module
 *
 * @details Loads and deserialize a term stored in the literal table and returns a term.
 * @param mod The module that owns that is going to be loaded.
 * @param index a valid literal index.
 */
extern term module_load_literal(Module *mod, int index);

#endif
