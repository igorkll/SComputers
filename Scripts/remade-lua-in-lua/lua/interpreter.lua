--в этом говно было дохера фиксов
--теперь оно более мения юзабельно
--и мения баговоное чем scrapVM

ll_Interpreter = {}

ll_Interpreter.interations = 0
ll_Interpreter.MAX_ITERATIONS = math.huge --I have restrictions not on the number of iterations, but on the execution time
ll_Interpreter.internalData = {}

local function tableToString(t)
    if type(t) ~= 'table' then return tostring(t) end
    local s = "{"

    for k, v in pairs(t) do
        s = s .. tostring(k) .. "=" .. tableToString(v) .. ', '
    end

    s = s:sub(1, #s - 2)

    return s .. "}"
end

local fakenil = {} --кастыль фиксяший сьежающие аргументы

ll_Interpreter.evals = {
    ['chunk'] = function(self, node, environment)
        local eval = __eval
        for _, statement in ipairs(node.statements) do
            --self:evaluate(statement, environment)

            local success, r = pcall(eval, self, statement, environment)

            if not success then
                if type(r) == 'table' then
                    if r.type == 'return_error' then return unpack(r.values) end
                    if r.type == 'break_error' then return end
                end
                error(r)
            end
        end
    end,
    ['block'] = function(self, node, environment)
        local eval = __eval
        for _, statement in ipairs(node.statements) do
            eval(self, statement, environment)
        end
    end,
    ['literal'] = function(self, node)
        return node.value
    end,
    ['assign'] = function(self, node, environment)
        local globals = self:getGlobal(environment)
        if not ll_Interpreter.internalData[globals[node.name]] then --а нехер перезаписывать __internal_yield, крашеры ебаные
            globals[node.name] = self:evaluate(node.value, environment) --Я ЭТУ ХУЙНЮ ЕЛЕ ФИКСАНУЛ!!! ТУТ ВМЕСТО environment ТУДА globals ХАУЯИЛИ
            --ИЗ ИЗ ЗА ЭТОГО ПИЗДЕЦА ВСЕ НЕ ЛЯМБДЫ НЕ ИМЕЛИ ДОСТУПА К ЛОКАЛЬНЫМ ПЕМЕННЫМ ОБЬВЛЕНЫМ ВЫЩЕ
        else
            error("failed to rewrite a mod-protected function", 2)
        end
    end,
    ['function'] = function(self, node, environment)
        return function(...)
            local func_env = self:encloseEnvironment(environment)
            local insert = table.insert

            for _, arg in ipairs(node.arg_names) do
                self:declareInEnv(func_env, arg)
            end

            local args = { ... }

            for i = 1, math.huge do
                if not node.arg_names[i] then break end
                func_env[node.arg_names[i]] = args[i] or fakenil
            end

            local varargs = {}
            if node.varargs then
                local new_args = {}
                local arg_l = #args
                local node_arg_l = #node.arg_names

                if arg_l > node_arg_l then
                    for i = node_arg_l + 1, arg_l do
                        local a = args[i]
                        insert(varargs, a)
                        insert(new_args, a)
                    end
                end
                func_env.arg = new_args
            end
            self:setEnvMeta(func_env, "varargs", varargs)

            return self:evaluate(node.body, func_env)
        end
    end,
    ["declare_local"] = function(self, node, environment)
        local values = self:evaluateExpressionList(node.values, environment)
        local decl = self.declareInEnv

        for _, var_name in ipairs(node.names) do
            decl(self, environment, var_name)
        end

        for i = 1, #node.names do
            local var_name = node.names[i]
            local value = values[i]

            if not ll_Interpreter.internalData[environment[var_name]] then --а нехер перезаписывать __internal_yield, крашеры ебаные
                environment[var_name] = value
            else
                error("failed to rewrite a mod-protected function", 2)
            end
        end
    end,
    ["assign_expr"] = function(self, node, environment)
        local values = self:evaluateExpressionList(node.values, environment)
        local eval = __eval
        local set = self.setInEnv

        for i = 1, #node.exprs do
            local target = node.exprs[i]
            local value = values[i]
            if target.type == "variable" then
                if not ll_Interpreter.internalData[environment[target.name]] then --а нехер перезаписывать __internal_yield, крашеры ебаные
                    set(self, environment, target.name, value)
                else
                    error("failed to rewrite a mod-protected function", 2)
                end
            else -- otherwise it's a get from table
                local table_value = eval(self, target.from, environment)
                local index = eval(self, target.index, environment)

                if not ll_Interpreter.internalData[table_value[index]] then --а нехер перезаписывать __internal_yield, крашеры ебаные
                    table_value[index] = value
                else
                    error("failed to rewrite a mod-protected function", 2)
                end
            end
        end
    end,
    ["get"] = function(self, node, environment)
        local eval = __eval

        local from = eval(self, node.from, environment)
        local index = eval(self, node.index, environment)

        return from[index]
    end,
    ["set"] = function(self, node, environment)
        local eval = __eval

        local in_value = eval(self, node.in_value, environment)
        local value = eval(self, node.value, environment)
        local index = eval(self, node.index, environment)

        if not ll_Interpreter.internalData[in_value[index]] then --а нехер перезаписывать __internal_yield, крашеры ебаные
            in_value[index] = value
        else
            error("failed to rewrite a mod-protected function", 2)
        end
    end,
    ["call"] = function(self, node, environment)
        local eval = __eval

        local callee = eval(self, node.callee, environment)
        local args = {}
        --local insert = table.insert

        for i, arg_node in ipairs(node.args) do --фиксанутые аргументы
            local values = { eval(self, arg_node, environment) }
            for i2, value in ipairs(values) do
                local pos = i + (i2 - 1)
                args[pos] = value
                for i3 = pos + 1, math.huge do
                    if not args[i3] then break end
                    args[i3] = nil
                end
            end
            --args[#args+1] = self:evaluate(arg_node, environment)
        end

        return callee(unpack(args))
    end,
    ["get_call"] = function(self, node, environment)
        local eval = __eval

        local callee = eval(self, node.callee, environment)
        local args = {}
        --local insert = table.insert

        for i, arg_node in ipairs(node.args) do --фиксанутые аргументы
            local values = { eval(self, arg_node, environment) }
            for i2, value in ipairs(values) do
                local pos = i + (i2 - 1)
                args[pos] = value
                for i3 = pos + 1, math.huge do
                    if not args[i3] then break end
                    args[i3] = nil
                end
            end
            --args[#args+1] = self:evaluate(arg_node, environment)
        end

        return callee[node.index](callee, unpack(args))
    end,
    ["variable"] = function(self, node, environment)
        return self:getFromEnv(environment, node.name)
    end,
    ["table"] = function(self, node, environment)
        local eval = __eval

        local tbl = {}
        local insert = table.insert

        local array_idx = 1
        for i, table_field in ipairs(node.fields) do --фиксанутое определения таблицы
            if table_field.array_item then
                local values = { eval(self, table_field.value, environment) }
                for i2, value in ipairs(values) do
                    local pos = i + (i2 - 1)
                    tbl[pos] = value

                    --потому что {1, (функция возврашяюшая несколько значений), 3}
                    --из этой функции только одно(первое значения) должно идти в таблицу(а если после него нечего нет то все)
                    --так это работает в нормальном lua, поэтому тут должно работать так же
                    --а аргументами фикс такой-же
                    for i3 = pos + 1, math.huge do
                        if not tbl[i3] then break end
                        tbl[i3] = nil
                    end
                end
            else
                local key = eval(self, table_field.key, environment)
                local value = eval(self, table_field.value, environment)

                if not ll_Interpreter.internalData[tbl[key]] then --а нехер перезаписывать __internal_yield, крашеры ебаные
                    tbl[key] = value
                else
                    error("failed to rewrite a mod-protected function", 2)
                end
            end
        end

        return tbl
    end,
    ['operation'] = function(self, node, environment)
        local eval = __eval

        local left = eval(self, node.left, environment)

        if node.operator == 'or' then
            if left then
                return left
            else
                return eval(self, node.right, environment)
            end
        elseif node.operator == 'and' then
            if left then
                return eval(self, node.right, environment)
            else
                return left
            end
        end

        local right = eval(self, node.right, environment)

        return self.operations[node.operator](left, right)
    end,
    ["if"] = function(self, node, environment)
        local eval = __eval
        local enclose = __enclose

        for _, clause in ipairs(node.clauses) do
            if eval(self, clause.expr, environment) then
                local new_env = enclose(self, environment)
                eval(self, clause.body, new_env)
                return
            end
        end

        if node.else_body then
            local new_env = enclose(self, environment)
            eval(self, node.else_body, new_env)
        end
    end,
    ["while"] = function(self, node, environment)
        local eval = __eval
        local enclose = __enclose

        while eval(self, node.expr, environment) do
            local new_env = enclose(self, environment)
            --self:evaluate(node.body, new_env)

            local success, r = pcall(eval, self, node.body, new_env)

            if not success then
                if type(r) == 'table' and r.type == 'break_error' then
                    return
                end
                error(r)
            end
        end
    end,
    ["repeat"] = function(self, node, environment)
        local eval = __eval
        local enclose = __enclose

        repeat
            local new_env = enclose(self, environment)
            --self:evaluate(node.body, new_env)

            local success, r = pcall(eval, self, node.body, new_env)

            if not success then
                if type(r) == 'table' and r.type == 'break_error' then
                    return
                end
                error(r)
            end
        until eval(self, node.expr, environment)
    end,
    ["for"] = function(self, node, environment)
        local eval = __eval
        local enclose = __enclose

        local start = eval(self, node.start, environment)
        local end_loop = eval(self, node.end_loop, environment)
        local step = eval(self, node.step, environment)

        local node_body = node.body

        for i = start, end_loop, step do
            local new_env = enclose(self, environment)
            new_env[node.var_name] = i
            --self:evaluate(node.body, new_env)

            local success, r = pcall(eval, self, node_body, new_env)

            if not success then
                if type(r) == 'table' and r.type == 'break_error' then
                    return
                end
                error(r)
            end
        end
    end,
    ["foreach"] = function(self, node, environment)
        local eval = __eval
        local evalList = __eval_list
        local enclose = __enclose
        local min = math.min

        local node_body = node.body

        do
            local f, s, var = unpack(evalList(self, node.expressions, environment))
            while true do
                local vars = { f(s, var) }
                if vars[1] == nil then break end
                var = vars[1]

                local new_env = enclose(self, environment)

                local loop = min(#node.variables, #vars)
                for i = 1, loop do
                    new_env[node.variables[i]] = vars[i]
                end

                --self:evaluate(node.body, new_env)

                local success, r = pcall(eval, self, node_body, new_env)

                if not success then
                    if type(r) == 'table' and r.type == 'break_error' then
                        return
                    end
                    error(r)
                end
            end
        end
    end,
    ["do"] = function(self, node, environment)
        local new_env = self:encloseEnvironment(environment)
        self:evaluate(node.body, new_env)
    end,
    ["return"] = function(self, node, environment)
        error { type = "return_error", values = self:evaluateExpressionList(node.values, environment) }
    end,
    ["break"] = function(self, node, environment)
        error { type = "break_error" }
    end,
    uminus = function(self, node, environment)
        return -(self:evaluate(node.value, environment))
    end,
    ['not'] = function(self, node, environment)
        return not (self:evaluate(node.value, environment))
    end,
    get_length = function(self, node, environment)
        return #self:evaluate(node.value, environment)
    end,
    varargs = function(self, node, environment)
        local varargs = self:getEnvVarargs(environment)
        return unpack(varargs)
    end,
    ['debugdmpenvstack'] = function(self, node, environment)
        --self:dumpEnv(environment)
    end
}

ll_Interpreter.operations = {
    PLUS = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l + r
    end,
    MINUS = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l - r
    end,
    STAR = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l * r
    end,
    SLASH = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l / r
    end,
    PRECENTAGE = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l % r
    end,
    UP = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l ^ r
    end,
    CONCAT = function(l, r)
        return l .. r
    end,
    LESS = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l < r
    end,
    LESS_EQUAL = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l <= r
    end,
    GREATER = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l > r
    end,
    GREATER_EQUAL = function(l, r)
        --assert(type(l) == "number", "attempt to perform arithmetic on a " .. type(l) .. " value (the first aggrumentum)")
        --assert(type(r) == "number", "attempt to perform arithmetic on a " .. type(r) .. " value (the second argument)")
        return l >= r
    end,
    DOUBLE_EQUALS = function(l, r)
        return l == r
    end,
    NOT_EQUAL = function(l, r)
        return l ~= r
    end
}

local globalStep = 0
function ll_Interpreter:evaluate(node, environment)
    local iter = self.interations + 1
    if iter >= self.MAX_ITERATIONS then
        error("Max interation count exeeded")
    end
    self.interations = iter

    if not self.evals[node.type] then
        --error("No evaluator found for node of type '" .. node.type .. "'\n" .. debug.traceback())
        error("No evaluator found for node of type '" .. node.type .. "'")
    end

    --if self.debug then
    --    print(node.type, tableToString(node))
    --end

    if node.tunnel then
        node.tunnel.lastEval = node
    end
    if node.serviceTable then
        if node.serviceTable.yield then
            if globalStep % 2048 == 0 then
                node.serviceTable.yield(node.serviceTable.yieldArg)
                globalStep = 1
            else
                globalStep = globalStep + 1
            end
        end
    end
    return self.evals[node.type](self, node, environment)
end

__eval = ll_Interpreter.evaluate


function ll_Interpreter:evaluateExpressionList(node_values, environment)
    local values = {}
    local insert = table.insert
    local eval = __eval

    for _, val in ipairs(node_values) do
        local returned = { eval(self, val, environment) }
        for _, returned_value in ipairs(returned) do
            insert(values, returned_value)
        end
    end

    return values
end

__eval_list = ll_Interpreter.evaluateExpressionList

function ll_Interpreter:getGlobal(environment)
    local mt = environment.__metatable
    if mt then
        local enclosing = mt.enclosing
        if enclosing then
            return self:getGlobal(enclosing)
        end
    end
    return environment
end

function ll_Interpreter:encloseEnvironment(enclosing)
    local mt = { enclosing = enclosing, declared = {} }
    local new_env = {}
    new_env.__metatable = mt
    return new_env
end

__enclose = ll_Interpreter.encloseEnvironment

function ll_Interpreter:getFromEnv(environment, key)
    if environment[key] == fakenil then
        return nil
    end

    if environment[key] ~= nil then
        return environment[key]
    end

    local mt = environment.__metatable
    if mt then
        local enclosing = mt.enclosing
        if enclosing then
            return self:getFromEnv(enclosing, key)
        end
    end

    return nil
end

function ll_Interpreter:dumpEnv(environment, level)
    local level = level or 0

    print('--- up level ' .. level .. ' ---')
    for k, v in pairs(environment) do
        print(k, v)
    end

    local mt = environment.__metatable
    if mt then
        local enclosing = mt.enclosing
        if enclosing then
            return self:dumpEnv(enclosing, level + 1)
        end
    end
end

function ll_Interpreter:declareInEnv(environment, key)
    local mt = environment.__metatable
    mt.declared[key] = true
    --setmetatable(environment, mt)
end

function ll_Interpreter:setInEnv(environment, key, value)
    if ll_Interpreter.internalData[environment[key]] then --а нехер перезаписывать __internal_yield, крашеры ебаные
        error("failed to rewrite a mod-protected function", 4)
    end

    if environment[key] then
        environment[key] = value
        return
    end

    local mt = environment.__metatable

    if mt and mt.declared and mt.declared[key] then
        environment[key] = value
        return
    end

    if mt then
        local enclosing = mt.enclosing
        if enclosing then
            return self:setInEnv(enclosing, key, value)
        end
    end

    -- reached global env
    environment[key] = value
end

function ll_Interpreter:setEnvMeta(environment, key, value)
    local mt = environment.__metatable or {}
    mt[key] = value
end

function ll_Interpreter:getEnvMeta(environment, key)
    local mt = environment.__metatable or {}
    return mt[key]
end

function ll_Interpreter:getEnvVarargs(environment)
    local mt = environment.__metatable or {}
    local varargs = mt.varargs
    if varargs then return varargs end
    local enclosing = mt.enclosing
    if enclosing then return self:getEnvVarargs(enclosing) end
end

function ll_Interpreter:reset()
    self.interations = 0
end

print("ll_Interpreter loaded")
