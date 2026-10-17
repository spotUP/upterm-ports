open(IN, "<in.txt") or die "open: $!";
open(OUT, ">out.txt") or die "open out: $!";
while (<IN>) {
    s/(\w+)=(\w+)/$2=$1/g;
    s/\b([a-z])(\w*)/\U$1\E$2/g;
    s/(\d+)/<$1>/;
    print OUT $_;
}
close(IN); close(OUT);
open(IN, "<out.txt") or die; print while <IN>; close(IN);
