#!/usr/bin/perl
package Record;

my $debug=0;

# constructor
sub new{
    my $class = shift;
    my $self = {
	    _priority=> shift,
	    _id => shift,
	    _subject => shift,
	    _updated_on => shift,
	    _count => shift,
    };

    if($debug eq 1){
        print "Record: priority is $self->{_priority}\n";
        print "Record: id is $self->{_id}\n";
        print "Record: subject is $self->{_subject}\n";
        print "Record: updated_on is $self->{_updated_on}\n";
        print "Record: count is $self->{_count}\n";
    }
    bless $self, $class;
    return $self;
}

sub getPriority {
    my( $self ) = @_;
    return $self->{_priority};
}

sub setPriority {
	my( $self, $priority ) = @_;
	$self->{_priority} = $priority if defined($prioirty);
	return $self->{_priority};
}

sub getID {
    my( $self ) = @_;
    return $self->{_id};
}

sub setID {
	my( $self, $id ) = @_;
	$self->{_id} = $id if defined($id);
	return $self->{_id};
}

sub getSubject {
    my( $self ) = @_;
    return $self->{_subject};
}

sub setSubject {
	my( $self, $subject ) = @_;
	$self->{_subject} = $subject if defined($subject);
	return $self->{_subject};
}

sub getCount {
    my( $self ) = @_;
    return $self->{_count};
}

sub setCount {
	my( $self, $count ) = @_;
	$self->{_count} = $count if defined($count);
	return $self->{_count};
}

sub toString {
	my( $self ) = @_;
	return "priority: $self->{_priority}, id: $self->{_id}, subject: $self->{_subject}, updated_on: $self->{_updated_on}, count: $self->{_count}";
}

sub toHTML {
    my( $self ) = @_;
    my $url_issues = "https://hub.tmaxsoft.com/redmine/issues";
    return "<tr><td>$self->{_priority}</td><td><a href=\"$url_issues/$self->{_id}\">$self->{_id}</a></td><td class=\"reminder_subject\">$self->{_subject}</td><td>$self->{_updated_on}</td><td>$self->{_count}</td>";
}
1;
