#!/usr/bin/perl --

use strict;
use DBI();

use lib ".";
use Record;
use Config::Tiny;

my $config = Config::Tiny->read( 'config.ini', 'utf8' );
 
my $database_name = $config->{database}{name};    
my $database_server = $config->{database}{server};  
my $database_user = $config->{database}{user};    
my $database_password = $config->{database}{password};
my $smtp_server = $config->{smtp}{server};    
my $smtp_user = $config->{smtp}{user};    
my $smtp_password = $config->{smtp}{password};    
my $smtp_ehlo = $config->{smtp}{ehlo};    
my $email_all = $config->{email}{all};   
my $email_from = $config->{email}{from};
my $email_subject = $config->{email}{subject};

#end of config

my $swaks="./swaks --auth ";
   $swaks.="--server $smtp_server ";
   $swaks.="--au $smtp_user ";
   $swaks.="--ap $smtp_password ";
   $swaks.="--h-Subject: $email_subject ";
   $swaks.="--from $email_from ";
   $swaks.="--ehlo $smtp_ehlo ";
   $swaks.='--add-header "MIME-Version: 1.0" --add-header "Content-Type: text/html" ';

my $boday_all='';
#my $email_all="maxpaper86\@gmail.com";
#my $email_all="peter.j.han\@tmaxsoft.com";

my $header="<html><head><style>td.reminder_subject {text-align: left;}";
   $header.="table, th, td { padding: 0px 4px 0px 4px; border: solid 1px #d7d7d7; border-collapse: collapse; text-align: center; font-family: \"Verdana\",sans-serif; }";
   $header.= "th { background: #EEEEEE; color: #116699; } </style></head><body>\n";
   $header.="<h4>Redmine Reminder Rules</h4>\n";
   $header.="<ul><li>Very High: Reminded when no action detected more than 1 days.</li><li>High: Reminded when no action detected more than 3 days.</li></ul>\n";
   $header.="<h4>Redmine Reminder Details</h4>\n";
my $footer='</body></html>';

my $previous_email='';
my $body='';
my $priority ='';
my $id ='';
my $subject ='';
my $updated_on = '';
my $count = 0;
my $email ='';

my @records = ();

sub push_email {
    my($priority, $id, $subject, $updated_on, $count) = @_;
    my $record = new Record($priority, $id, $subject, $updated_on, $count);
    push(@records, $record);
}

sub send_email {
    print "send_email\n";
    my($email) = @_;
    if(scalar @records eq 0){
	print "send_email: empty";
        return();
    }

    $body="<h3>$email</h3>\n<table>\n<thread><tr><th>Priority</th><th>ID</th><th>Subject</th><th>Updated on</th><th>Reminder count</th></tr></thread><tbody>";
    for my $record (@records){
	my $record_html=$record->toHTML();
	$body.="$record_html\n";
    }
    $body.="</tbody></table><br/>\n";

    my $command=$swaks;
    $command.="--to $email ";
    $command.="--body '$header\n$body\n$footer\n'";

    print "send_email: $header\n$body\n$footer\n";
    $boday_all.="$body";
}

sub send_email_all {
    if($email_all  eq ''){
        return();
    }
    if($boday_all eq ''){
        return();
    }
   
    my $command=$swaks;
    $command.="--to $email_all ";
    $command.="--body '$header\n$boday_all\n$footer\n' ";

    print "send_email_all: $header\n$boday_all\n$footer\n";
    system("./swaks $command");
}

my $dbh = DBI->connect("DBI:mysql:database=$database_name;host=$database_server", $database_user, $database_password, {'RaiseError' => 1});
my $project_id='68';


my $reminder_query = qq{select 
 enumerations.name as priority, issues.id as id, issues.subject as subject, email_addresses.address as email,
 issues.updated_on as updated_on
 from enumerations
 join issues on issues.priority_id = enumerations.id
 join email_addresses on email_addresses.user_id = issues.assigned_to_id
 join projects on projects.id = issues.project_id
 where 
 (issues.closed_on is NULL) and
 (issues.project_id=68 or projects.parent_id=68) and
 (issues.tracker_id=3) and
 (
 ((enumerations.id=3) and (issues.updated_on < NOW() - INTERVAL 3 DAY)) or
 ((enumerations.id=4) and (issues.updated_on < NOW() - INTERVAL 1 DAY))
 )
 ORDER BY `email` ASC, `priority` DESC, `id` ASC
}  ;


my $rows = $dbh->selectall_arrayref($reminder_query, { Slice => {} }) or die "Error: ".$dbh->errstr;


for my $row ( @$rows ){
    $priority = $row->{'priority'};
    $id = $row->{'id'};
    $subject = $row->{'subject'};
    $subject=~ s/\'/\'\'/g;
    $updated_on= $row->{'updated_on'};
    $count = 0;
    $email = $row->{'email'};
  


    if ($previous_email eq $email){
	push_email($priority, $id, $subject, $updated_on, $count);
    }
    elsif ($previous_email eq ''){
	push_email($priority, $id, $subject, $updated_on, $count);
    }
    else{
        send_email($previous_email);
        @records = ();
	push_email($priority, $id, $subject, $updated_on, $count);
    }
    $previous_email = $email;
}
send_email($previous_email);
send_email_all();

