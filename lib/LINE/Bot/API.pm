package LINE::Bot::API;
use strict;
use warnings;
our $VERSION = '1.06';

use JSON::XS;
use URI;

use LINE::Bot::API::Builder::SendMessage;
use LINE::Bot::API::Client;
use LINE::Bot::API::Event;
use LINE::Bot::API::Response::Common;
use LINE::Bot::API::Response::Content;
use LINE::Bot::API::Response::NumberOfSentMessages;
use LINE::Bot::API::Response::Profile;
use LINE::Bot::API::Response::IssueLinkToken;
use LINE::Bot::API::Response::RichMenu;
use LINE::Bot::API::Response::RichMenuList;

sub new {
    my($class, %args) = @_;

    my $client = LINE::Bot::API::Client->new(%args);

    bless {
        client               => $client,
        channel_secret       => $args{channel_secret},
        channel_access_token => $args{channel_access_token},
        messaging_api_endpoint     => $args{messaging_api_endpoint}   // 'https://api.line.me/v2/bot/',
    }, $class;
}

sub request {
    my ($self, $method, $path, @payload) = @_;

    return $self->{client}->$method(
        $self->{messaging_api_endpoint} .  $path,
        @payload,
    );
}

sub reply_message {
    my($self, $reply_token, $messages) = @_;

    my $res = $self->request(
        post => 'message/reply',
        +{
            replyToken => $reply_token,
            messages   => $messages,
        }
    );

    LINE::Bot::API::Response::Common->new(%{ $res });
}

sub push_message {
    my($self, $to_id, $messages) = @_;

    my $res = $self->request(
        post => 'message/push',
        +{
            to       => $to_id,
            messages => $messages,
        }
    );
    LINE::Bot::API::Response::Common->new(%{ $res });
}

sub multicast {
    my($self, $to_ids, $messages) = @_;

    my $res = $self->request(
        post => 'message/multicast',
        +{
            to       => $to_ids,
            messages => $messages,
        }
    );
    LINE::Bot::API::Response::Common->new(%{ $res });
}

sub get_message_content {
    my($self, $message_id, %options) = @_;
    my $res = $self->request(
        'contents_download' => "message/$message_id/content",
        %options
    );
    LINE::Bot::API::Response::Content->new(%{ $res });
}

sub get_profile {
    my($self, $user_id) = @_;
    my $res = $self->request(get => "profile/$user_id");
    LINE::Bot::API::Response::Profile->new(%{ $res });
}

sub leave_room {
    my($self, $room_id) = @_;
    my $res = $self->request(post => "room/$room_id/leave", +{});
    LINE::Bot::API::Response::Common->new(%{ $res });
}

sub leave_group {
    my($self, $group_id) = @_;
    my $res = $self->request(post => "group/$group_id/leave", +{});
    LINE::Bot::API::Response::Common->new(%{ $res });
}

sub get_number_of_sent_reply_messages {
    my($self, $date) = @_;
    my $res = $self->request(get => "message/delivery/reply?date=${date}");
    LINE::Bot::API::Response::NumberOfSentMessages->new(%{ $res });
}

sub get_number_of_sent_push_messages {
    my($self, $date) = @_;
    my $res = $self->request(get => "message/delivery/push?date=${date}", +{});
    LINE::Bot::API::Response::NumberOfSentMessages->new(%{ $res });
}

sub get_number_of_sent_multicast_messages {
    my($self, $date) = @_;
    my $res = $self->request(get => "message/delivery/multicast?date=${date}", +{});
    LINE::Bot::API::Response::NumberOfSentMessages->new(%{ $res });
}

sub validate_signature {
    my($self, $json, $signature) = @_;
    LINE::Bot::API::Event->validate_signature($json, $self->{channel_secret}, $signature);
}

sub parse_events_from_json {
    my($self, $json) = @_;
    LINE::Bot::API::Event->parse_events_json($json);
}

sub issue_link_token {
    my($self, $user_id) = @_;
    my $res = $self->request(post => "user/${user_id}/linkToken", +{});
    LINE::Bot::API::Response::IssueLinkToken->new(%{ $res });
}

sub create_rich_menu {
    my ($self, $rich_menu) = @_;
    my $res = $self->request(post => "richmenu", $rich_menu);
    LINE::Bot::API::Response::RichMenu->new(%{ $res });
}

sub get_rich_menu {
    my ($self, $rich_menu_id) = @_;
    my $res = $self->request(get => "richmenu/${rich_menu_id}");
    LINE::Bot::API::Response::RichMenu->new(%{ $res });
}


sub get_rich_menu_list {
    my ($self) = @_;
    my $res = $self->request(get => "richmenu/list");
    LINE::Bot::API::Response::RichMenuList->new(%{ $res });
}

1;
__END__

=head1 NAME

LINE::Bot::API - SDK of the LINE Messaging API for Perl

=for html <a href="https://travis-ci.org/line/line-bot-sdk-perl"><img src="https://travis-ci.org/line/line-bot-sdk-perl.svg?branch=master"></a>

=head1 SYNOPSIS

    # in the synopsis.psgi
    use strict;
    use warnings;
    use LINE::Bot::API;
    use LINE::Bot::API::Builder::SendMessage;
    use Plack::Request;

    my $bot = LINE::Bot::API->new(
        channel_secret       => $channel_secret,
        channel_access_token => $channel_access_token,
    );

    sub {
        my $req = Plack::Request->new(shift);

        unless ($req->method eq 'POST' && $req->path eq '/callback') {
            return [200, [], ['Not Found']];
        }

        unless ($bot->validate_signature($req->content, $req->header('X-Line-Signature'))) {
            return [200, [], ['failed to validate signature']];
        }

        my $events = $bot->parse_events_from_json($req->content);
        for my $event (@{ $events }) {
            next unless $event->is_message_event && $event->is_text_message;

            my $messages = LINE::Bot::API::Builder::SendMessage->new;
            $messages->add_text( text => $event->text );
            $bot->reply_message($event->reply_token, $messages->build);
        }

        return [200, [], ["OK"]];
    };

=head1 DESCRIPTION

LINE::Bot::API is a client library which lets you easily start using the LINE Messaging API.
You can create a bot which runs on the LINE app by registering for a LINE Messaging API account.
You can create a B<Messaging API> account from the L<LINE Business Center|https://business.line.me/>.

You can find the B<Channel secret> and B<Channel access token> on the Basic information page on the Channel Console which you can access from the L<LINE Business Center|https://business.line.me/>.

Use this documentation and the LINE Developers documentation to get you started developing your own bot!

=head1 METHODS

=head2 new(%args)

Create a new LINE::Bot::API instance.

     my $bot = LINE::Bot::API->new(
        channel_secret       => $channel_secret,
        channel_access_token => $channel_access_token,
    );

=head2 reply_message($reply_token, [ $message, ... ] )

Send reply messages to a user, room or group.

    my $messages = LINE::Bot::API::Builder::SendMessage->new;
    $messages->add_text( text => 'Example reply text' );

    my $ret = $bot->reply_message($reply_token, $messages->build);
    unless ($ret->is_success) {
        # error
        warn $ret->message;
        for my $detail (@{ $ret->details // []}) {
            warn "    detail: " . $detail->{message};
        }
    }

You can get a C<reply_token> from a L<webhook event object|https://developers.line.biz/en/reference/messaging-api/#webhook-event-objects>.
See the documentation for the C<parse_events_from_json($json)> method.

See also the API reference of this method: L<https://developers.line.biz/en/reference/messaging-api/#send-reply-message>

=head2 push_message($user_id|$room_id|$group_id, [ $message, ... ])

Send push messages to a user, room or group.

    my $messages = LINE::Bot::API::Builder::SendMessage->new;
    $messages->add_text( text => 'Example push text' );
    $bot->push_message($user_id, $messages->build);

You can get a C<user_id>, C<room_id> or C<group_id> from a L<webhook event object|https://developers.line.biz/en/reference/messaging-api/#webhook-event-objects>
See the documentation for the C<parse_events_from_json($json)> method.

See also the LINE Developers API reference of this method: L<https://developers.line.biz/en/reference/messaging-api/#send-push-message>

=head2 multicast([$user_id, ... ], [ $message, ... ])

Send push messages to multiple users.

    my $messages = LINE::Bot::API::Builder::SendMessage->new;
    $messages->add_text( text => 'Example push text' );
    $bot->multicast([ $user_id ], $messages->build);

You can get a C<user_id> from a L<webhook event object|https://developers.line.biz/en/reference/messaging-api/#webhook-event-objects>.
See the documentation for the C<parse_events_from_json($json)> method.

See also the LINE Developers API reference of this method: L<https://developers.line.biz/en/reference/messaging-api/#send-multicast-messages>

=head2 validate_signature($json, $signature)

    my $req = Plack::Request->new( ... );
    unless ($bot->validate_signature($req->content, $req->header('X-Line-Signature'))) {
        die 'failed to signature validation';
    }

=head2 parse_events_from_json($json)

Parse webhook event objects and build L<LINE::Bot::API::Event> instances.

    my $req = Plack::Request->new( ... );
    my $events = $bot->parse_events_from_json($req->content);
    for my $event (@{ $events }) {
        unless ($event->is_unfollow_event && $event->is_leave_event) {
            # Get a reply_token
            my $reply_token = $event->reply_token;
        }
        if ($event->is_user_event) {
            # Get a user_id
            my $user_id = $event->user_id;
        }
        if ($event->is_room_event) {
            # Get a room_id
            my $room_id = $event->room_id;
        }
        if ($event->is_group_event) {
            # Get a group_id
            my $group_id = $event->group_id;
        }

        if ($event->is_message_event) {
            # Get a message id
            my $message_id = $event->message_id;
        }
    }

=head2 leave_room($room_id)

Bot leaves a room.

    $bot->leave_room($room_id);

You can get a C<room_id> by a L<Webhook Event Object|https://developers.line.biz/en/reference/messaging-api/#webhook-event-objects>.
And see also C<parse_events_from_json($json)> method's document.

=head2 leave_group($group_id)

Bot leaves a group.

    $bot->leave_group($group_id);

You can get a C<group_id> from a L<webhook event object|https://developers.line.biz/en/reference/messaging-api/#webhook-event-objects>.
See the documentation for the C<parse_events_from_json($json)> method.

=head2 get_message_content($message_id)

Get the original file which was sent by user.

    my $ret = $bot->get_message_content($message_id);
    if ($ret->is_success) {
        my $filename = $ret->fh->filename;
        open my $fh, '<', $file or die "$!: $file";
        ...
    }

You can get a C<message_id> from a L<webhook event object|https://developers.line.biz/en/reference/messaging-api/#webhook-event-objects>.
See the documentation for the C<parse_events_from_json($json)> method.

You can also see the online API reference documentation.

See also the LINE Developers API reference of this method: L<https://developers.line.biz/en/reference/messaging-api/#get-content>

=head2 get_profile($user_id)

Get user profile information.

    my $ret = $bot->get_profile($user_id);
    if ($ret->is_success) {
        say $ret->display_name;
        say $ret->user_id;
        say $ret->picture_url;
        say $ret->status_message;
    }

See also the LINE Developers API reference of this method:  L<https://developers.line.biz/en/reference/messaging-api/#get-profile>

=head2 C<< get_number_of_sent_reply_messages($date) >>

Gets the number of messages sent with the C<< /bot/message/reply >> endpoint.

The number of messages retrieved by this operation does not include
the number of messages sent from LINE@ Manager.

The C<< $date >> parameter is "yyyyMMdd" format.

=head2 C<< get_number_of_sent_push_messages($date) >>

Gets the number of messages sent with the C<< /bot/message/push >> endpoint.

The number of messages retrieved by this operation does not include the number of messages sent from LINE@ Manager.

=over 4

=item date

Date the messages were sent

    Format: yyyyMMdd (Example: 20191231)
    Timezone: UTC+9

=back

=head2 C<< get_number_of_sent_multicast_messages($date) >>

Gets the number of messages sent with the C<< /bot/message/multicast >> endpoint.

The number of messages retrieved by this operation does not include the number of messages sent from LINE@ Manager.

=over 4

=item date

Date the messages were sent

    Format: yyyyMMdd (Example: 20191231)
    Timezone: UTC+9

=back

=head2 C<<create_rich_menu( $rich_menu_object )>>

This method correspond to the API of L<Creating rich menu|https://developers.line.biz/en/reference/messaging-api/#create-rich-menu>

One argument is needed: C<$rich_menu_object>, which is a plain HashRef representing L<rich menu object|https://developers.line.biz/en/reference/messaging-api/#rich-menu-object>

=head2 C<<get_rich_menu( $rich_menu_id )>>

This method correspond to the API of L<Get rich menu|https://developers.line.biz/en/reference/messaging-api/#get-rich-menu>

One argument is needed: $rich_menu_id -- which correspond to the
richMenuId property of the object returned by C<create_rich_menu>
method.

=head2 C<<get_rich_menu_list>>

This method correspond to the API of L<Get rich menu list|https://developers.line.biz/en/reference/messaging-api/#get-rich-menu-list>

No arguments are needed.

=head2 How to build a send message object

See the LINE Developers API reference about L<Message objects|https://developers.line.biz/en/reference/messaging-api/#message-objects>

When the C<LINE::Bot::API::Builder::SendMessage> class is used, it is possible easily to build a send message object.
That class supports a fluent interface.

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_text(
        text => 'Closing the distance',
    )->add_image(
        image_url   => 'http://example.com/image.jpg',
        preview_url => 'http://example.com/image_preview.jpg',
    );
    $bot->reply_message($reply_token, $messages->build);

=head3 Text type

Build a text type object.

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_text(
        text => 'Closing the distance',
    );
    $bot->reply_message($reply_token, $messages->build);

=head3 Image type

Build an image type object.

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_image(
        image_url   => 'http://example.com/image.jpg',
        preview_url => 'http://example.com/image_preview.jpg',
    );
    $bot->reply_message($reply_token, $messages->build);

=head3 Video type

Build a video type object.

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_video(
        video_url   => 'http://example.com/video.mp4',
        preview_url => 'http://example.com/video_preview.jpg',
    );
    $bot->reply_message($reply_token, $messages->build);

=head3 Audio type

Build an audio type object.

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_audio(
        audio_url => 'http://example.com/image.m4a',
        duration  => 3601_000, # msec
    );
    $bot->reply_message($reply_token, $messages->build);

=head3 Location type

Build a location type object.

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_location(
        title     => 'LINE Corporation.',
        address   => 'Hikarie  Shibuya-ku Tokyo 151-0002',
        latitude  => 35.6591,
        longitude => 139.7040,
    );
    $bot->reply_message($reply_token, $messages->build);

=head3 Sticker type

Build a sticker type object.

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_sticker(
        package_id => '1',
        sticker_id => '2',
    );
    $bot->reply_message($reply_token, $messages->build);

=head3 Imagemap type

Build an imagemap type object.
You can use a helper module for the imagemap type.

    my $imagemap = LINE::Bot::API::Builder::ImagemapMessage->new(
        base_url    => 'https://example.com/bot/images/rm001',
        alt_text    => 'this is an imagemap',
        base_width  => 1040,
        base_height => 1040,
    )->add_uri_action(
        uri         => 'http://example.com/',
        area_x      => 0,
        area_y      => 0,
        area_width  => 1040,
        area_height => 520,
    )->add_message_action(
        text        => 'message',
        area_x      => 0,
        area_y      => 520,
        area_width  => 1040,
        area_height => 520,
    );

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_imagemap($imagemap->build);
    $bot->reply_message($reply_token, $messages->build);

=head3 Template type

Build a template type object.
You can use a helper module for the template type.

=head4 Buttons type

    my $buttons = LINE::Bot::API::Builder::TemplateMessage->new_buttons(
        alt_text  => 'this is a buttons template',
        image_url => 'https://example.com/bot/images/image.jpg',
        title     => 'buttons',
        text      => 'description',
    )->add_postback_action(
        label => 'postback',
        data  => 'postback data',
        text  => 'postback message',
    )->add_message_action(
        label => 'message',
        text  => 'message',
    )->add_uri_action(
        label => 'uri',
        uri   => 'http://example.com/',
    )->add_message_action(
        label => 'message2',
        text  => 'message2',
    );

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_template($buttons->build);
    $bot->reply_message($reply_token, $messages->build);

=head4 Confirm type

    my $confirm = LINE::Bot::API::Builder::TemplateMessage->new_confirm(
        alt_text => 'this is a confirm template',
        text     => 'confirm',
    )->add_postback_action(
        label => 'postback',
        data  => 'postback data',
        text  => 'postback message',
    )->add_message_action(
        label => 'message',
        text  => 'message',
    )->add_uri_action(
        label => 'uri',
        uri   => 'http://example.com/',
    );

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_template($confirm->build);
    $bot->reply_message($reply_token, $messages->build);

=head4 Carousel type

    my $carousel = LINE::Bot::API::Builder::TemplateMessage->new_carousel(
        alt_text => 'this is a carousel template',
    );
    for my $i (1..5) {
        my $column = LINE::Bot::API::Builder::TemplateMessage::Column->new(
            image_url => 'https://example.com/bot/images/item.jpg',
            title     => "carousel $i",
            text      => "description $i",
        )->add_postback_action(
            label => 'postback',
            data  => 'postback data',
            text  => 'postback message',
        )->add_message_action(
            label => 'message',
            text  => 'message',
        )->add_uri_action(
            label => 'uri',
            uri   => 'http://example.com/',
        );
        $carousel->add_column($column->build);
    }

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_template($carousel->build);
    $bot->reply_message($reply_token, $messages->build);

=head4 Image Carousel type

    my $carousel = LINE::Bot::API::Builder::TemplateMessage->new_image_carousel(
        alt_text => 'this is a image carousel template',
    );

    my $column1 = LINE::Bot::API::Builder::TemplateMessage::ImageColumn->new(
        image_url => 'https://example.com/bot/images/item1.jpg',
    )->add_postback_action(
        label => 'postback',
        data  => 'postback data',
        text  => 'postback message',
    );
    $carousel->add_column($column1->build);

    my $column2 = LINE::Bot::API::Builder::TemplateMessage::ImageColumn->new(
        image_url => 'https://example.com/bot/images/item2.jpg',
    )->add_message_action(
        label => 'message',
        text  => 'message',
    );
    $carousel->add_column($column2->build);

    my $column3 = LINE::Bot::API::Builder::TemplateMessage::ImageColumn->new(
        image_url => 'https://example.com/bot/images/item3.jpg',
    )->add_uri_action(
        label => 'uri',
        uri   => 'http://example.com/',
    );
    $carousel->add_column($column3->build);

    my $messages = LINE::Bot::API::Builder::SendMessage->new(
    )->add_template($carousel->build);
    $bot->reply_message($reply_token, $messages->build);

=head1 COPYRIGHT & LICENSE

Copyright 2016 LINE Corporation

This Software Development Kit is licensed under The Artistic License 2.0.
You may obtain a copy of the License at
https://opensource.org/licenses/Artistic-2.0

=head1 SEE ALSO

L<LINE::Bot::API::Event>,
L<https://developers.line.biz/>,
L<https://at.line.me/>

=cut
