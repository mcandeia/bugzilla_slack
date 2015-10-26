# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# This Source Code Form is "Incompatible With Secondary Licenses", as
# defined by the Mozilla Public License, v. 2.0.
#####################################################################
# Codigo de extensao para o slack do bugzilla                       #
#                                                                   #
#                                                                   #
# Author: Marcos V. Candeia                                         #
#####################################################################

package Bugzilla::Extension::Bugzilla_slack;
use HTTP::Request::Common;
use JSON;
use Data::Dumper;
use strict;
use base qw(Bugzilla::Extension);

require LWP::UserAgent;

# Hooks do bugzilla https://www.bugzilla.org/docs/tip/en/html/api/Bugzilla/Hook.html
# This code for this is in ./extensions/Bugzilla_slack/lib/Util.pm
#use Bugzilla::Extension::Bugzilla_slack::Util;

our $VERSION = '0.01';
# Config
our $TOKEN_BOT = 'ADD_TOKEN_HERE'; # REPLACE WITH YOUR TOKEN
our $CHANNEL = '%23bugzilla';
our $USERNAME = 'bugzillabot';
our $CHANNEL_POST = 'https://slack.com/api/chat.postMessage?as_user=true&token=' . $TOKEN_BOT . '&channel=' . $CHANNEL . '&username=' . $USERNAME .'&text=';
our $CHAT_POST = 'https://slack.com/api/chat.postMessage?as_user=true&token=' . $TOKEN_BOT . '&username=' . $USERNAME .'&text=';
our $USERS_LIST = 'https://slack.com/api/users.list?presence=1&token=' . $TOKEN_BOT;
our $OPEN_CHAT = 'https://slack.com/api/im.open?token=' . $TOKEN_BOT . '&user=';
our $UA = LWP::UserAgent->new;
our $BUGZILLA_URI = 'http://localhost:8080'; # REPLACE WITH YOUR BUGZILLA_URI

sub bug_end_of_update {
    my ($self, $args) = @_;
    my $user = Bugzilla->user->name;
    my ($bug, $old_bug, $changes) =
        @$args{qw(bug old_bug changes)};
    my $id = $bug->id;
    # EXTRAINDO OS CAMPOS

    my $summary = $bug->short_desc;
    my $bug_id = $bug->id;
    my $bug_status = $bug->status->name;
    my $assigned_to = $bug->assigned_to->name;
    my $bug_severity = $bug->bug_severity;
    my $component = $bug->component;
    my $UC = $bug->cf_caso_de_uso;
    # Formatando a mensagem usando as regras do markdown mais em: https://slack.zendesk.com/hc/en-us/articles/202288908-Formatting-your-messages
    my $MSG_POST = join "", '<' . $BUGZILLA_URI . '/show_bug.cgi?id=' , $id, '|Bug ', $id, ': _', $summary, '_> foi atualizado por : _', $user, "_";

    # Campos dos anexos
    my $fields = join ",",_get_field('Atribuído para', $assigned_to, 'true'), _get_field("Status", $bug_status, "true"), _get_field("Severidade", $bug_severity, "true"), _get_field("Componente", $component, "true");
    my $json_string = join "", '[{"color":"%23ff0000", "text":"","fields":[',$fields, ']', "}]";
    my $json = $json_string;
    # Formando as urls de envio de mensagem
    my $URL_CHANNEL = join "", $CHANNEL_POST, $MSG_POST, "&attachments=", $json;
    # Extraindo o usuario do slack
    my $user_assigned = _get_slack_user($assigned_to);

    # MANDA PARA O CANAL DO BUGZILLA
    my $req = HTTP::Request->new(POST => $URL_CHANNEL);
    $req->header('content-type' => 'application/json');
    $UA->request($req);
    # MANDA PARA O USUARIO QUE O BUG FOI ASSINALADO
    my $user_id = _get_user_id_by_name($user_assigned);
    my $user_channel = _get_channel_by_user_id($user_id);
    # Envia por chat private usando o bot do bugzilla
    my $URL_CHAT = join "", $CHAT_POST, $MSG_POST, '&channel=', $user_channel, "&attachments=", $json;
    my $req = HTTP::Request->new(POST => $URL_CHAT);
    $req->header('content-type' => 'application/x-www-form-urlencoded');
    $UA->request($req);
}
# Retorna o usuário do slack a partir do realname. Ex: Marcos Candeia fica marcos.candeia
sub _get_slack_user {
    my($real_name) = @_;
    # extraindo o usuario do slack o primeiro passo eh colocar o nome em lower case, logo apos separa-los por espaco
    my @names = split(" ", lc $real_name);
    # Seleciona os dois primeiros nomes da pessoa e os junta com um '.'
    return join("." ,($names[0], $names[1]));
}
# Retorna o ID do usuario de acordo com seu login ($user_assigned)
sub _get_user_id_by_name {
    my ($user_assigned) = @_;
    my $users_req = HTTP::Request->new(GET => $USERS_LIST);
    $users_req->header('content-type' => 'application/json');
    my $content = $UA->request($users_req)->content;
    my $decoded_json = decode_json($content);
    my $members = $decoded_json->{'members'};
    # Encontra qual id do usuario no slack a partir do seu realname
    foreach my $member (@{$members}) {
        my $member_name = $member->{'name'};
        if($member_name eq $user_assigned) {
            return $member->{'id'};
        }
    }
}

# Retorna o canal para falar em private com o respectivo $user_id
sub _get_channel_by_user_id {
    my($user_id) = @_;
    if (!defined($user_id)) {
	return "";
    }
    my $url = join "", $OPEN_CHAT, $user_id;
    my $req = HTTP::Request->new(POST => $url);
    $req->header('content-type' => 'application/json');
    my $content = $UA->request($req)->content;
    my $decoded_json = decode_json($content);
    return $decoded_json->{'channel'}->{'id'};
}
#Retorna a representacao em JSON de um campo em um anexo
sub _get_field {
    my ($title, $value, $short) = @_;
    return join "",'{"short":', $short, ',"title":"', $title,'","value":"', $value, '"}';
}
__PACKAGE__->NAME;
