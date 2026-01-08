#pragma once
#include <iostream>
#include <string>
#include <vector>
#include <variant>
#include <cmath>
#include "SymbolTable.hpp"
#include "Context.hpp"

using namespace std;

class ASTNode {
public:
    ASTNode* left;
    ASTNode* right;
    
    // Node metadata
    string root; // Stores the operator ("+", "-", ":<") or Variable Name or "CONST"
    string node_type; // "OPERATOR", "IDENTIFIER", "CONSTANT"
    
    // Value for constants
    SymbolTable::VariableData val; 

    // Constructor for Binary Operators
    ASTNode(string op, ASTNode* left, ASTNode* right) 
        : root(op), left(left), right(right), node_type("OPERATOR") {}

    // Constructor for Variables (Identifiers)
    ASTNode(string var_name) 
        : root(var_name), left(nullptr), right(nullptr), node_type("IDENTIFIER") {}

    // Constructor for Constants
    ASTNode(SymbolTable::VariableData v) 
        : val(v), left(nullptr), right(nullptr), node_type("CONSTANT"), root("CONST") {}

    ~ASTNode() { 
        if(left) delete left; 
        if(right) delete right; 
    }

    // Helper to get a zero value for a type (used for default returns / errors)
    SymbolTable::VariableData get_default_val() {
        return 0; // Default to int 0
    }

    SymbolTable::VariableData eval(SymbolTable* table) {
        // 1. Constants
        if (node_type == "CONSTANT") {
            return val;
        }

        // 2. Identifiers (Variable Lookup)
        if (node_type == "IDENTIFIER") {
            if (table) {
                // If checking for NULL/nullptr, make sure the loopup is correct
                SymbolTable::VarSymbol* sym = table->get_var(root);
                if (sym) {
                    return sym->data;
                } else {
                    // It might be a parameter or local variable not yet initialized if checking strictly declarations
                    // But get_var traverses scopes, so if not found, it's really missing.
                    cerr << "Error: Variable '" << root << "' not found." << endl;
                    return get_default_val();
                }
            }
            return get_default_val();
        }

        // 3. Operators
        if (node_type == "OPERATOR") {
            // Assignment ":<"
            if (root == ":<") {
                // 1. Assign to Variable
                if (left && left->node_type == "IDENTIFIER") {
                    SymbolTable::VariableData res = right->eval(table);
                    if (table) {
                         SymbolTable::VarSymbol* sym = table->get_var(left->root);
                         if (sym) {
                             sym->data = res;
                         } else {
                             cerr << "Error: Cannot assign to undeclared variable '" << left->root << "'." << '\n';
                         }
                    }
                    return res;
                } 
                // 2. Assign to Object Property (left is "->")
                else if (left && left->root == "->") {
                    if (left->left && left->right) {
                        SymbolTable::VariableData objVal = left->left->eval(table);
                        string fieldName = left->right->root;
                        
                        if (holds_alternative<SymbolTable::ClassInstance*>(objVal)) {
                            auto instance = get<SymbolTable::ClassInstance*>(objVal);
                            if (instance) {
                                SymbolTable::VariableData res = right->eval(table);
                                // For assignment, we might create the property if we allow dynamic properties, 
                                // but assume strict structure if implied. 
                                // SymbolTable usually implies strict structure for fields, but ClassInstance uses a map.
                                // We can just insert checks.
                                instance->properties[fieldName] = res; 
                                return res;
                            }
                        }
                    }
                }
                return get_default_val();
            }

            // Member Access "->"
            if (root == "->") {
                if (left && right && right->node_type == "IDENTIFIER") {
                     SymbolTable::VariableData objVal = left->eval(table);
                     string fieldName = right->root;
                     
                     if (holds_alternative<SymbolTable::ClassInstance*>(objVal)) {
                         auto instance = get<SymbolTable::ClassInstance*>(objVal);
                         if (instance) {
                             if (instance->properties.count(fieldName)) {
                                 return instance->properties[fieldName];
                             } else {
                                 cerr << "Error: Field '" << fieldName << "' not found in object." << endl;
                             }
                         } else {
                             cerr << "Error: Object is null." << endl;
                         }
                     } else {
                         cerr << "Error: Left side of '->' is not an object." << endl;
                     } 
                     return get_default_val();
                }
            }

            // Binary Operations
            // Evaluate both sides first
            SymbolTable::VariableData v1 = left->eval(table);
            SymbolTable::VariableData v2 = right->eval(table);

            if (root == "+") return add(v1, v2);
            if (root == "-") return sub(v1, v2);
            if (root == "*") return mul(v1, v2);
            if (root == "/") return div(v1, v2);
            if (root == "%") return mod(v1, v2);
            
            if (root == "&&") return log_and(v1, v2);
            if (root == "||") return log_or(v1, v2);
            
            if (root == "==") return eq(v1, v2);
            if (root == "!=") return neq(v1, v2);
            if (root == "<") return lt(v1, v2);
            if (root == ">") return gt(v1, v2);
            if (root == "<=") return le(v1, v2);
            if (root == ">=") return ge(v1, v2);
            
            // Pointer/Object access "->"
            if (root == "->") {
                 // v1 is the object instance
                 // v2 .. wait, evaluating right side of -> (the field name) as a variable might fail if it's not a standalone var.
                 // The right child of "->" is usually an ID, but it shouldn't be evaluated as a variable in the scope. 
                 // It should be treated as a string literal field name.
                 // HOWEVER, our eval recursively evaluates children.
                 // We should specialized check for "->" to NOT evaluate the right child if it is just a field name.
                 
                 // CORRECTION: Re-implementing "->" logic to avoid evaluating right child as a scope variable
            }
        }
        
        return get_default_val();
    }
    
    // Corrected logic for operators that need special handling of children (like ->)
    // Actually, I should check root BEFORE evaluating children for those cases.
    
    // BUT, the recursive structure above evaluates v1 and v2 unconditionally for binary ops.
    // I need to split the logic.

private:
   // Helper arithmetic functions for types in std::variant
    SymbolTable::VariableData add(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<int>(v1) && holds_alternative<int>(v2))
            return get<int>(v1) + get<int>(v2);
        if (holds_alternative<float>(v1) && holds_alternative<float>(v2))
            return get<float>(v1) + get<float>(v2);
        if (holds_alternative<int>(v1) && holds_alternative<float>(v2))
            return (float)get<int>(v1) + get<float>(v2);
        if (holds_alternative<float>(v1) && holds_alternative<int>(v2))
            return get<float>(v1) + (float)get<int>(v2);
        if (holds_alternative<string>(v1) && holds_alternative<string>(v2))
            return get<string>(v1) + get<string>(v2);
        return 0;
    }

    SymbolTable::VariableData sub(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<int>(v1) && holds_alternative<int>(v2))
            return get<int>(v1) - get<int>(v2);
        if (holds_alternative<float>(v1) && holds_alternative<float>(v2))
            return get<float>(v1) - get<float>(v2);
        return 0;
    }

    SymbolTable::VariableData mul(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
         if (holds_alternative<int>(v1) && holds_alternative<int>(v2))
            return get<int>(v1) * get<int>(v2);
        if (holds_alternative<float>(v1) && holds_alternative<float>(v2))
            return get<float>(v1) * get<float>(v2);
        return 0;
    }

    SymbolTable::VariableData div(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<int>(v2) && get<int>(v2) == 0) { cout << "Div by 0" << endl; return 0; }
        if (holds_alternative<int>(v1) && holds_alternative<int>(v2))
            return get<int>(v1) / get<int>(v2);
        if (holds_alternative<float>(v1) && holds_alternative<float>(v2))
            return get<float>(v1) / get<float>(v2);
        return 0;
    }

    SymbolTable::VariableData mod(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<int>(v1) && holds_alternative<int>(v2))
            return get<int>(v1) % get<int>(v2);
        return 0;
    }
    
    SymbolTable::VariableData eq(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (v1.index() != v2.index()) return false;
        if (holds_alternative<int>(v1)) return get<int>(v1) == get<int>(v2);
        if (holds_alternative<float>(v1)) return get<float>(v1) == get<float>(v2);
        if (holds_alternative<bool>(v1)) return get<bool>(v1) == get<bool>(v2);
        if (holds_alternative<string>(v1)) return get<string>(v1) == get<string>(v2);
        return false;
    }
    
    SymbolTable::VariableData neq(SymbolTable::VariableData v1, SymbolTable::VariableData v2) { return !get<bool>(eq(v1,v2)); }
    
    SymbolTable::VariableData lt(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<int>(v1) && holds_alternative<int>(v2)) return get<int>(v1) < get<int>(v2);
        if (holds_alternative<float>(v1) && holds_alternative<float>(v2)) return get<float>(v1) < get<float>(v2);
        return false;
    }
    SymbolTable::VariableData gt(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<int>(v1) && holds_alternative<int>(v2)) return get<int>(v1) > get<int>(v2);
        if (holds_alternative<float>(v1) && holds_alternative<float>(v2)) return get<float>(v1) > get<float>(v2);
        return false;
    }
    SymbolTable::VariableData le(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<int>(v1) && holds_alternative<int>(v2)) return get<int>(v1) <= get<int>(v2);
        return false;
    }
    SymbolTable::VariableData ge(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<int>(v1) && holds_alternative<int>(v2)) return get<int>(v1) >= get<int>(v2);
        return false;
    }
    SymbolTable::VariableData log_and(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<bool>(v1) && holds_alternative<bool>(v2)) return get<bool>(v1) && get<bool>(v2);
        return false;
    }
    SymbolTable::VariableData log_or(SymbolTable::VariableData v1, SymbolTable::VariableData v2) {
        if (holds_alternative<bool>(v1) && holds_alternative<bool>(v2)) return get<bool>(v1) || get<bool>(v2);
        return false;
    }

};
