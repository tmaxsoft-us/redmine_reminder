#!/usr/bin/perl

use strict;
use Getopt::Long;
use DBI();

use lib ".";
use Record;
use Config::Tiny;

my $dbh;
my $is_debug=0;
my $is_update=0;
my $config_path='';

my $body_all='';
my $body='';
my @records = ();

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

my $header="<html><head><style>td.reminder_subject {text-align: left;}";
$header.="table, th, td { padding: 0px 4px 0px 4px; border: solid 1px #d7d7d7; border-collapse: collapse; text-align: center; font-family: \"Verdana\",sans-serif; }";
$header.= "th { background: #EEEEEE; color: #116699; } </style></head><body>\n";
$header.="<h4>Redmine Reminder Rules</h4>\n";
$header.="<ul><li>Very High: Reminded when no action detected more than 2 days.</li><li>High: Reminded when no action detected more than 4 days.</li></ul>\n";
$header.="<h4>Redmine Reminder Details</h4>\n";
my $footer='</body></html>';

sub push_email {
    my($priority, $id, $subject, $updated_on, $reminder_count) = @_;
    my $record = new Record($priority, $id, $subject, $updated_on, $reminder_count);
    push(@records, $record);
}

sub send_email {
    my($email) = @_;
    if(scalar @records eq 0){
        if($is_debug eq 1) { print "[DEBUG] send_email: empty\n"; }
        return();
    }

    $body="<h3>$email</h3>\n<table>\n<thread><tr><th>Priority</th><th>ID</th><th>Subject</th><th>Updated on</th><th>Reminder Count</th></tr></thread><tbody>";
    for my $record (@records){
        my $record_html=$record->toHTML();
        $body.="$record_html\n";
    }
    $body.="</tbody></table><br/>\n";

    my $command=$swaks;
    $command.="--to $email ";
    $command.="--body '$header\n$body\n$footer\n'";

    if($is_debug eq 1) { print "[DEBUG] send_email: $header\n$body\n$footer\n"; }
    system("./swaks $command");

    $body_all.="$body";

    @records = ();
}

sub send_email_all {
    if($email_all  eq ''){
        return();
    }
    if($body_all eq ''){
        return();
    }

    my $command=$swaks;
    $command.="--to $email_all ";
    $command.="--body '$header\n$body_all\n$footer\n' ";

    if($is_debug eq 1) { print "[DEBUG] send_email_all: $header\n$body_all\n$footer\n"; }
    system("./swaks $command");
}

sub load_config {
    my($config_path) = @_;
    if($config_path eq "")
    {
        $config_path = 'config.ini';
    }

    if(-e $config_path){
        if($is_debug eq 1) { print "[DEBUG] config_path: $config_path\n"; }
    }
    else
    {
        print "[ERROR] config file not found: $config_path\n";
        return();
    }

    $config = Config::Tiny->read( $config_path, 'utf8' );

    $database_name = $config->{database}{name};    
    $database_server = $config->{database}{server};  
    $database_user = $config->{database}{user};    
    $database_password = $config->{database}{password};

    $smtp_server = $config->{smtp}{server};    
    $smtp_user = $config->{smtp}{user};    
    $smtp_password = $config->{smtp}{password};    
    $smtp_ehlo = $config->{smtp}{ehlo};    

    $email_all = $config->{email}{all};   
    $email_from = $config->{email}{from};
    $email_subject = $config->{email}{subject};
}

sub main {
    my $previous_email='';

    my $priority ='';
    my $id ='';
    my $subject ='';
    my $updated_on = '';
    my $reminder_count = 0;
    my $email ='';

    GetOptions( 'config=s' => \ $config_path
        , 'update!' => \ $is_update
        , 'debug!' => \ $is_debug
    );

    if($is_debug eq 1){
        print "[DEBUG] config['config']: $config_path\n";
        print "[DEBUG] config['update']: $is_update\n";
        print "[DEBUG] config['debug']: $is_debug\n";
        if($is_update eq 0)
        {
            if($is_debug eq 1) { print "[DEBUG]: --update is not specified. ignoring table update.\n" };
        }
    }

    $dbh = DBI->connect("DBI:mysql:database=$database_name;host=$database_server", $database_user, $database_password, {'RaiseError' => 1});
    $dbh->{AutoCommit} = 0;

    my $create_statement = qq{CREATE TABLE IF NOT EXISTS tmaxsoft_redmine_reminders(
            id INT AUTO_INCREMENT PRIMARY KEY,
            issue_id INT NOT NULL UNIQUE,
            count INT DEFAULT 1)
    };

    $dbh->do($create_statement);

    my $reminder_statement = qq{select 
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
            ((enumerations.id=3) and (issues.updated_on < NOW() - INTERVAL 4 DAY)) or
            ((enumerations.id=4) and (issues.updated_on < NOW() - INTERVAL 2 DAY))
        )
        ORDER BY `email` ASC, `priority` DESC, `id` ASC
    };

    my $rows = $dbh->selectall_arrayref($reminder_statement, { Slice => {} }) or die "Error: ".$dbh->errstr;
    my $rows_count = scalar @$rows;
    if($is_debug eq 1) { print "[DEUBG] rows_count: $rows_count\n"; }

    for my $row ( @$rows ){
        $priority = $row->{'priority'};
        $id = $row->{'id'};
        $subject = $row->{'subject'};
        $subject=~ s/\'/\'\'/g;
        $updated_on= $row->{'updated_on'};
        $email = $row->{'email'};
        $reminder_count = -1;

        my $statement = "SELECT count FROM tmaxsoft_redmine_reminders WHERE issue_id=?";
        my $reminders = $dbh->selectall_arrayref($statement, { Slice => {} }, $id);
        for my $reminder ( @$reminders ){
            $reminder_count = $reminder->{'count'};
        }

        if($is_update eq 1){	
            if($reminder_count eq -1)
            {
                if($is_debug eq 1) { print "[DEBUG]: INSERT INTO tmaxsoft_redmine_reminders(issue_id) VALUES ($id)\n"; }
                my $insert_sth = $dbh->prepare("INSERT INTO tmaxsoft_redmine_reminders(issue_id) VALUES (?)");
                $insert_sth->bind_param(1, $id);
                $insert_sth->execute;
            }
            else 
            {
                $reminder_count = $reminder_count+1;
                if($is_debug eq 1) { print "[DEBUG]: UPDATE tmaxsoft_redmine_reminders SET count=$reminder_count where issue_id=$id\n"; }
                my $update_sth = $dbh->prepare("UPDATE tmaxsoft_redmine_reminders SET count=? where issue_id=?");
                $update_sth->bind_param(1, $reminder_count);
                $update_sth->bind_param(2, $id);
                $update_sth->execute;
            }
        }

        if ($previous_email eq $email){
            push_email($priority, $id, $subject, $updated_on, $reminder_count);
        }
        elsif ($previous_email eq ''){
            push_email($priority, $id, $subject, $updated_on, $reminder_count);
        }
        else{
            send_email($previous_email);
            push_email($priority, $id, $subject, $updated_on, $reminder_count);
        }
        $previous_email = $email;
    }
    send_email($previous_email);
    send_email_all();

    $dbh->commit or die $dbh->errstr;
    $dbh->disconnect;
}

main();
