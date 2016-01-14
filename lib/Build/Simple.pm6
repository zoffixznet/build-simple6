unit class Build::Simple;
use fatal;
class Node { ... }
has Node:D %!nodes;
my subset Filename of Any:D where { $_ ~~ Str|IO::Path };

method add-file(Filename:D $name, :dependencies(@dependency-names), *%args) {
	die "Already exists" if %!nodes{$name} :exists;
	die "Missing dependencies" unless %!nodes{all(@dependency-names)} :exists;
	my Node:D @dependencies = @dependency-names.map: { %!nodes{$^dep} };
	%!nodes{$name} = Build::Simple::Node.new(|%args, :name(~$name), :@dependencies, :!phony);
	return;
}

method add-phony(Filename:D $name, :dependencies(@dependency-names), *%args) {
	die "Already exists" if %!nodes{$name} :exists;
	die "Missing dependencies" unless %!nodes{all(@dependency-names)} :exists;
	my Node:D @dependencies = @dependency-names.map: { %!nodes{$^dep} };
	%!nodes{$name} = Build::Simple::Node.new(|%args, :name(~$name), :@dependencies, :phony);
	return;
}

method !nodes-for(Str:D $name) {
	my %seen;
	sub node-sorter($node) {
		node-sorter($_) for $node.dependencies.grep: { !%seen{$^node}++ };
		take $node;
	}
	return gather { node-sorter(%!nodes{$name}) };
}

method _sort-nodes(Str:D $name) {
	self!nodes-for($name).map(*.name);
}

method run(Filename:D $name, *%args) {
	for self!nodes-for(~$name) -> $node {
		$node.run(%args)
	}
	return;
}

my class Node {
	has Str:D $.name is required;
	has Bool:D $.phony = False;
	has Bool:D $.skip-mkdir = ?$!phony;
	has Node:D @.dependencies;
	has Sub $.action;
	my sub make-parent(IO::Path $file) {
		my $parent = $file.parent.IO;
		if not $parent.d {
			make-parent($parent);
			$parent.mkdir;
		}
	}

	method run (%options) {
		if !$!phony {
			my $file = $!name.IO;
			if $file.e {
				my $files = @!dependencies.grep(!*.phony).map(*.name.IO);
				my $age = $file.modified;
				return unless $files.grep: { $^entry.modified > $age && !$^entry.d };
			}
			make-parent($file) unless $!skip-mkdir;
		}
		$!action.(:$!name, :@!dependencies, |%options) if $!action;
	}
}
