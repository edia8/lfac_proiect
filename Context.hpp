#ifndef CONTEXT_HPP
#define CONTEXT_HPP

#include "SymbolTable.hpp"

class Context {
    SymbolTable* global_scope;
    SymbolTable* current_scope;

public:
    Context() {
        global_scope = new SymbolTable("global");
        current_scope = global_scope;
    }

    // Enter a manually created scope (for funcs/classes)
    void enter_scope(SymbolTable *child_scope) {
        current_scope->add_child_scope(child_scope);
        current_scope = child_scope;
    }

    // Create and enter a new anonymous scope (for blocks)
    void enter_new_block_scope(const std::string& name) {
        SymbolTable* new_scope = new SymbolTable(name, current_scope);
        current_scope->add_child_scope(new_scope);
        current_scope = new_scope;
    }

    void exit_scope() {
        if (current_scope->parent) {
            current_scope = current_scope->parent;
        } else {
            std::cout << "error: cannot exit global scope\n";
        }
    }

    SymbolTable* get_current_scope() { return current_scope; }
    SymbolTable* get_global_scope() { return global_scope; }
};

#endif