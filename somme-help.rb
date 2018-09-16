dest = ''

def b(s,n,m);k=0;k+=1 while (s+k)%m!=n;k;end
def to_grid(str)
    s =     str.split "\n"
    maxlen = s.map(&:length).max
    s.map { |l| l.ljust(maxlen).chars }
end
prog = <<EOF.chomp
Print@Sum@Twice!ReadInt
EOF
dest = dest.ljust prog.size
class Array;def sum;inject(0,:+);end;end
def gsum(arr)
    arr.map { |e| e.ord - 32 } .sum
end
tr = to_grid(prog).transpose
puts prog
tr.map.with_index { |col, i|
    a = b(gsum(col), dest[i].ord - 32, 95)
    print (a+32).chr
}
print dest[tr.size..-1]