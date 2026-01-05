#ifndef SYMBOL_TABLE_HPP
#define SYMBOL_TABLE_HPP

#include <iostream>
#include <map>
#include <memory>
#include <string>
#include <variant>
#include <vector>

class SymbolTable {
   public:
    std::string name;
    SymbolTable* parent;
    std::vector<SymbolTable*> child_scopes;

    //variabile
    enum class VariableType { INT, FLOAT, STRING, BOOL, OBJECT };

    // Container for data: Includes pointer to ClassInstance
    struct ClassInstance;
    using VariableData =
        std::variant<int, float, std::string, bool, ClassInstance*>;

    // Structure for Custom Class Instances
    struct ClassInstance {
        std::string class_name;
        std::map<std::string, VariableData> properties;

        ClassInstance(std::string name) : class_name(name) {}
    };

    // clasa ajutatoare pentru a printa din std::variant
    struct VarPrinter {
        FILE* out;

        VarPrinter(FILE* f) : out(f) {}

        void operator()(int v) { fprintf(out, "%d", v); }
        void operator()(float v) { fprintf(out, "%f", v); }
        void operator()(bool v) { fprintf(out, "%s", v ? "true" : "false"); }
        void operator()(const std::string& v) {
            fprintf(out, "\"%s\"", v.c_str());
        }

        void operator()(ClassInstance* v) {
            if (v)
                fprintf(out, "[Instance of %s]", v->class_name.c_str());
            else
                fprintf(out, "null");
        }
        /// pentru funtia print din SymbolTable
        std::string operator [] (const VariableType& t){
            switch (t){
                case VariableType::INT      : return "int";
                case VariableType::FLOAT    : return "float";
                case VariableType::STRING   : return "string";
                case VariableType::BOOL     : return "bool";
                case VariableType::OBJECT   : return "costum type";
            }
            return "unknown";
        }
    };

    class VarSymbol {
       public:
        VariableType type;
        std::string name;
        std::string custom_type_name;
        VariableData data;

        // Constructor with default arguments (also acts as default constructor)
        VarSymbol(VariableType t = VariableType::INT, std::string n = "",
                  VariableData d = 0)
            : type(t), name(n), data(d) {}

        void set_custom_type(std::string type_name) {
            custom_type_name = type_name;
        }
    };
    std::map<std::string, VarSymbol> vars;

    
    void add_var(const std::string& type_str, const std::string& var_name,
                 const VariableData& data) {
        if (vars.count(var_name)) {
            std::cerr << "Error: Variable '" << var_name
                      << "' already declared in scope '" << name << "'.\n";
            return;
        }

        VariableType t;
        std::string object_type = "";

        if (type_str == "INT")
            t = VariableType::INT;
        else if (type_str == "FLOAT")
            t = VariableType::FLOAT;
        else if (type_str == "STRING")
            t = VariableType::STRING;
        else if (type_str == "BOOL")
            t = VariableType::BOOL;
        else {
            t = VariableType::OBJECT;
            object_type = type_str;
        }

        VarSymbol sym(t, var_name, data);
        if (!object_type.empty()) {
            sym.set_custom_type(object_type);
            // If it's an object, initialize it with a new instance
            if (std::holds_alternative<int>(data) && std::get<int>(data) == 0) {
                sym.data = (ClassInstance*)new ClassInstance(object_type);
            }
        }
        vars[var_name] = sym;
    }

    VarSymbol* get_var(const std::string& var_name) {
        if (vars.find(var_name) != vars.end()) return &vars[var_name];
        if (parent) return parent->get_var(var_name);
        return nullptr;
    }

    // functii
    class FuncSymbol {
       public:
        std::string return_type;
        SymbolTable* scope;
        std::vector<std::pair<std::string, std::string>> params;

        FuncSymbol(std::string rt, SymbolTable* s, std::vector<std::pair<std::string, std::string>> p)
            : return_type(rt), scope(s), params(p) {};
        FuncSymbol() : scope(nullptr) {};
    };
    std::map<std::string, FuncSymbol> funcs;

    void add_func(const std::string& return_type, const std::string& func_name,
                  const std::vector<std::pair<std::string,std::string>>& params,
                  SymbolTable* func_scope) {
        if (funcs.count(func_name)) {
            std::cerr << "Error: Function '" << func_name
                      << "' already exists in " << name << "\n";
            return;
        }
        funcs[func_name] = FuncSymbol(return_type, func_scope, params);
    }

    FuncSymbol* get_func(const std::string& func_name) {
        if (funcs.find(func_name) != funcs.end()) return &funcs[func_name];
        if (parent) return parent->get_func(func_name);
        return nullptr;
    }

    // clase
    class ClassSymbol {
       public:
        SymbolTable* scope;
        ClassSymbol(SymbolTable* scope) : scope(scope) {};
        ClassSymbol() : scope(nullptr) {};
    };

    std::map<std::string, ClassSymbol> classes;

    void add_class(const std::string& class_name, SymbolTable* class_scope) {
        if (classes.count(class_name)) {
            std::cerr << "Error: Class '" << class_name
                      << "' already exists in " << name << "\n";
            return;
        }
        classes[class_name] = ClassSymbol(class_scope);
    }

    ClassSymbol* find_class(const std::string& class_name) {
        if (classes.find(class_name) != classes.end())
            return &classes[class_name];
        if (parent) return parent->find_class(class_name);
        return nullptr;
    }

    
    SymbolTable(std::string name, SymbolTable* parent = nullptr)
        : name(name), parent(parent) {}

    SymbolTable* add_child_scope(SymbolTable* child_scope) {
        child_scopes.push_back(child_scope);
        return child_scope;
    }

    // functie de printare debug
    void print(FILE* out, int indent = 0) {
        if (!out) return;

        std::string pad(indent, ' ');

        
        fprintf(out, "%sScope: %s, parent: %s\n", pad.c_str(), name.c_str(), (parent ? parent->name.c_str() : "-"));

        //printeaza variabile
        if (!vars.empty()) {
            fprintf(out, "%s  Variables:\n", pad.c_str());

            // Initialize printer with the out pointer
            VarPrinter var_printer(out);

            for (const auto& [name, var] : vars) {
                fprintf(out, "%s    %s (%s) = ", pad.c_str(), name.c_str(), var_printer[var.type].c_str());
                std::visit(var_printer, var.data);
                fprintf(out, "\n");
            }
        }

        //printeaza functii
        if (!funcs.empty()) {
            fprintf(out, "%s  Functions:\n", pad.c_str());
            for (const auto& [name, func] : funcs) {
                fprintf(out, "%s    %s %s(", pad.c_str(),
                        func.return_type.c_str(), name.c_str());
                for (size_t i = 0; i < func.params.size(); ++i) {
                    fprintf(out, "%s: %s%s", func.params[i].first.c_str(), func.params[i].second.c_str(),
                            (i < func.params.size() - 1 ? ", " : ""));
                }
                fprintf(out, ")\n");
            }
        }

        //printeaza clase
        if (!classes.empty()) {
            fprintf(out, "%s  Classes:\n", pad.c_str());
            for (const auto& [name, cls] : classes) {
                fprintf(out, "%s    %s\n", pad.c_str(), name.c_str());
            }
        }

        // printeaza recursiv pentru child_scopes
        for (auto child : child_scopes) {
            child->print(out, indent + 4);

        }
    }
};

#endif