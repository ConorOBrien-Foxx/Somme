require 'io/console'

def to_grid(str)
    s =     str.split "\n"
    maxlen = s.map(&:length).max
    s.map { |l| l.ljust(maxlen).chars }
end

def simp_type(i)
    begin
        return i.send(:map){ |e| simp_type e }
    rescue
        return i.to_i if i.is_a? Numeric and i == i.to_i
        return i
    end
end

$stdin_read = ""

def getch
    if STDIN.tty?
        char = STDIN.getch
        exit(1) if char == "\x03"
    else
        if $stdin_read.empty?
            $stdin_read = STDIN.gets
        end
        char = $stdin_read.slice! 0
    end
    char
end

def all_input
    STDIN.read
end

class Somme
    @@ops = {}
    def initialize(prog, options = {})
        @codes = to_grid(prog).transpose.map { |col|
            col.map { |e| e.ord - 32 } .inject(0, :+) % 95
        }
        @ops = @@ops
        @stack = []
        @stack_stack = []
        @index = 0
        @running = true
        @last_push = 42
        @reg = 100
        @options = options
    end
    
    attr_accessor :stack, :stack_stack, :index, :running, :last_push, :codes, :ops, :reg
    
    def step
        unless @running && @index < @codes.size
            @running = false
            return nil
        end
        code = @codes[@index]
        exec(code)
        @index += 1
    end
    
    def run
        step while @running
    end
    
    def exec(code)
        unless @@ops.has_key? code
            if @options["silent"]
                return
            else
                raise "opcode #{code} (\"#{(code + 32).chr}\") does not exist"
            end
        end
        op = @ops[code]
        arity = op.arity
        while @stack.size < arity
            @stack.push @last_push
        end 
        args = @stack.pop arity
        res = op[self, *args]
        @last_push = res if arity == 0
        @stack.push *res unless res == nil
        @stack.map! { |e| simp_type e }
        return
    end
    
    def self.set_op(key, op)
        unless op.instance_of? Op
            raise "#{op} should have been an Op, got a `#{op.class.name}`"
        end
        if @@ops.has_key? key
            raise "#{key} (#{(key + 32).chr}) already exists in @@ops."
        end
        @@ops[key] = op
    end
    
    def self.get_ops
        @@ops
    end
end

class Func
    def initialize(body)
        @body = body
    end
    
    def exec(somme)
        @body.each { |code|
            somme.exec(code)
        }
    end
    
    def over(*args)
        inst = Somme.new @body.map { |e| (e + 32).chr } .join
        inst.stack = args
        inst.run
        inst.stack.pop
    end
end

class Op
    def initialize(key, op, use_inst = false)
        @key = key
        @op = op
        @use_inst = use_inst
        Somme.set_op(key.ord - 32, self)
    end
    
    def [](*a)
        a.shift unless @use_inst || !a[0].is_a?(Somme)
        @op[*a]
    end
    
    def to_s
        "Op { #{@key} }"
    end
    
    def arity
        @op.arity - (@use_inst ? 1 : 0)
    end
    
    def inspect
        self.to_s
    end
end

# todo: make new stack for `to_base`

def to_base(a, b)
    return [a] if a == 1 or a == 2
    maxlen = Math.log(a + 1, b).ceil
    base_nums = Array.new maxlen, 0
    while a > 0
        c = Math.log(a, b).floor
        rm = b ** c
        a -= rm
        i = maxlen - c - 1
        base_nums[i] += 1
    end
    base_nums
end

Op.new ?0, -> { 0 }
Op.new ?1, -> { 1 }
Op.new ?2, -> { 2 }
Op.new ?3, -> { 3 }
Op.new ?4, -> { 4 }
Op.new ?5, -> { 5 }
Op.new ?6, -> { 6 }
Op.new ?7, -> { 7 }
Op.new ?8, -> { 8 }
Op.new ?9, -> { 9 }
Op.new ?A, -> { 10 }
Op.new ?B, -> { 11 }
Op.new ?C, -> { 12 }
Op.new ?D, -> { 13 }
Op.new ?E, -> { 14 }
Op.new ?F, -> { 15 }
Op.new ".", -> z { print simp_type z; z }
Op.new ",", -> z { print z.to_i.chr; z }
Op.new ":", -> z { [z, z] }
Op.new "i", -> z { z + 1 }
Op.new "I", -> z { z - 1 }
Op.new "t", -> z { z + 2 }
Op.new "T", -> z { z - 2 }
Op.new "b", -> inst, a, b {
    inst.ops["[".ord - 32][inst, 0]
    inst.stack = to_base a, b
    nil
}, true
Op.new "d", -> z { z * 2 }
Op.new "G", -> z { z / 2 }
Op.new "j", -> z { z - 3 }
Op.new "J", -> z { z + 3 }
Op.new "h", -> z { z / 3 }
Op.new "H", -> z { z * 3 }
Op.new "s", -> z { z * z }
Op.new "S", -> z { Math.sqrt z }
Op.new "%", -> a, b { a % b }
Op.new "f", -> a { a.floor }
Op.new "g", -> a { a.ceil }
Op.new "+", -> a, b { a + b }
Op.new "-", -> a, b { a - b }
Op.new "*", -> inst, a, b {
    if a.is_a? Func and b.is_a? Func
        raise "ne method `*` for Func, Func"
    elsif a.is_a? Func
        b.times { a.exec(inst) }; nil
    elsif b.is_a? Func
        a.times { b.exec(inst) }; nil
    else
        a * b
    end
}, true
Op.new "/", -> a, b { a * 1.0 / b }
Op.new "p", -> a, b { a ** b }
Op.new "P", -> a, b { Math.log a, b }
Op.new "m", -> inst {
    inst.index += 1
    next_op = inst.codes[inst.index]
    op = Somme.get_ops[next_op]
    inst.stack.map! { |e| op[e] }
    inst.stack.reject! { |e| e == nil }
}, true
Op.new "M", -> inst, f {
    inst.stack.map! { |e| f.over(e) }
    inst.stack.reject! { |e| e == nil }
}, true
Op.new "`", -> inst {
    body = []
    until inst.codes[inst.index + 1] == 64 or inst.codes.size <= inst.index
        body.push inst.codes[inst.index += 1]
    end
    inst.index += 1
    Func.new body
}, true
Op.new "~", -> inst {
    inst.index += 1
    next_op = inst.codes[inst.index]
    Func.new [next_op]
}, true
Op.new "!", -> inst, f {
    f.exec(inst)
    nil
}, true
Op.new "$", -> z { }
Op.new "@", -> inst, f {
    inst.index += 1
    redef = inst.codes[inst.index]
    Op.new (redef + 32).chr, -> inst {
        f.exec(inst)
        nil
    }, true
    nil
}, true
Op.new "^", -> inst, v {
    inst.reg = v
    nil
}, true
Op.new "v", -> inst {
    inst.reg
}, true
Op.new "#", -> a { a }
Op.new "\\", -> a, b { [b, a] }
Op.new "r", -> inst { inst.stack.reverse!; nil }, true
Op.new " ", -> {}
Op.new ";", -> a { exit a }
Op.new "L", -> inst, f {
    until inst.stack.last == 0
        f.exec(inst)
    end
}, true
Op.new "l", -> inst { inst.stack.size }, true
Op.new "n", -> { STDIN.gets.to_i }
Op.new "c", -> { getch.ord }
Op.new "&", -> inst {
    all_input.chars.map &:ord
}, true
Op.new "'", -> inst {
    until inst.codes[inst.index + 1] == 7 or inst.codes.size <= inst.index
        inst.index += 1
    end
    inst.index += 1
    nil
}, true
Op.new '"', -> inst, a {
    res = inst.reg
    inst.reg = a
    res
}, true
Op.new "[", -> inst, n {
    new_stack = inst.stack.pop(n)
    inst.stack_stack.push inst.stack.clone
    inst.stack = new_stack
    nil
}, true
Op.new "]", -> inst {
    nst = inst.stack_stack.pop
    inst.stack = nst.concat inst.stack
    nil
}, true
Op.new "}", -> inst {
    inst.stack.push inst.stack.shift
    nil
}, true
Op.new "{", -> inst {
    inst.stack.unshift inst.stack.pop
    nil
}, true

if __FILE__ == $0
    if ARGV.size == 0
        puts "usage: ruby somme.rb <filename>"
        puts "       ruby somme.rb -e \"code\""
        exit 0
    end
    opt = ARGV[0]
    options = {}
    if "-/".include?(opt[0])
        if opt.include? "e"
            prog = ARGV[1]
        else
            prog = File.read ARGV[1]
        end
        options["silent"] = true if opt.include? "s"
        options["display"] = true if opt.include? "p"
    else
        prog = File.read ARGV[0]
    end
    inst = Somme.new prog, options
    inst.run
    if options["display"]
        p simp_type inst.stack_stack
        p simp_type inst.stack.map
    end
end