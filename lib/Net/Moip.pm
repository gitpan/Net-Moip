package Net::Moip;

use IO::Socket::SSL;
use MIME::Base64;
use Furl;

use String::CamelCase ();
use XML::SAX::Writer;
use XML::Generator::PerlData;

use Moo;

our $VERSION = 0.01;

has 'ua', is => 'ro', default => sub {
    Furl->new(
        agent         => "Net-Moip/$VERSION",
        timeout       => 5,
        max_redirects => 3,
        ssl_opts => { SSL_verify_mode => SSL_VERIFY_PEER() }
    );
};

has 'token', is => 'ro', required => 1;

has 'key', is => 'ro', required => 1;

has 'api_url', (
    is      => 'ro',
    writer  => '_set_api_url',
    default => 'https://www.moip.com.br/ws/alpha/EnviarInstrucao/Unica'
);

has 'sandbox', (
    is      => 'rw',
    default => 0,
    trigger => sub {
        my ($self, $sandbox) = @_;
        $self->_set_api_url( $sandbox
            ? 'https://desenvolvedor.moip.com.br/sandbox/ws/alpha/EnviarInstrucao/Unica'
            : 'https://www.moip.com.br/ws/alpha/EnviarInstrucao/Unica'
        );
    }
);

sub pagamento_unico {
    my ($self, $args) = @_;

    my $xml  = $self->_gen_xml( $args );
    my $auth = 'Basic ' . MIME::Base64::encode( $self->token . ':' . $self->key, '');

    my $res = $self->ua->post(
        $self->api_url,
        [ 'Authorization' => $auth ],
        $xml
    );

    my %data = ( response => $res );
    if ($res->is_success) {
        my $c = $res->content;
        $data{id}     = $1 if $c =~ m{<ID>(.+?)</ID>};
        $data{status} = $1 if $c =~ m{<Status>(.+?)</Status>};
        $data{token}  = $1 if $c =~ m{<Token>(.+?)</Token>};

        while ($c =~ m{<Erro Codigo="(\d+)">(.+?)</Erro>}gs) {
            push @{$data{erros}}, { codigo => $1, mensagem => $2 };
        }
    }

    return \%data;
}

sub _gen_xml {
    my ($self, $args) = @_;
    my $xml;

    my $generator = XML::Generator::PerlData->new(
        Handler  => XML::SAX::Writer->new(Output => \$xml),
        rootname => 'EnviarInstrucao',
        keymap   => { '*' => \&String::CamelCase::camelize },
        attrmap  => { InstrucaoUnica => ['TipoValidacao']  },
    );

    no autovivification;

    $args->{valores}{valor} = delete $args->{valor};

    if (my $acrescimo = delete $args->{acrescimo}) {
        $args->{valores}{acrescimo} = $acrescimo;
    }

    if (my $deducao = delete $args->{deducao}) {
        $args->{valores}{deducao} = $deducao;
    }

    if (my $cep = delete $args->{pagador}{endereco_cobranca}{cep}) {
        $args->{pagador}{endereco_cobranca}{CEP} = $cep;
    }

    my $xml_args  = { instrucao_unica => $args };

    $generator->parse( $xml_args );

    return $xml;
}

1;
__END__
=encoding utf8

=head1 NAME

Net::Moip - Interface com o gateway de pagamentos Moip

=head1 SYNOPSE

    use Net::Moip;

    my $gateway = Net::Moip->new(
        token => 'MY_MOIP_TOKEN',
        key   => 'MY_MOIP_KEY',
    );

    my $res = $gateway->pagamento_unico({
        razao          => 'Pagamento para a Loja X',
        tipo_validacao => 'Transparente',
        valor          => 59.90,
        id_proprio     => 1,
        pagador => {
            id_pagador => 1,
            nome       => 'Cebolácio Júnior Menezes da Silva',
            email      => 'cebolinha@exemplo.com',
            endereco_cobranca => {
                logradouro    => 'Rua do Campinho',
                numero        => 9,
                bairro        => 'Limoeiro',
                cidade        => 'São Paulo',
                estado        => 'SP',
                pais          => 'BRA',
                cep           => '11111-111',
                telefone_fixo => '(11)93333-3333',
            },
        },
    });

    if ($res->{status} eq 'Sucesso') {
        print $res->{token};
        print $res->{id};
    }

=head2 Don't speak portuguese?

This module provides an interface to talk to the Moip API. Moip is a
popular brazilian online payments gateway. Since the target audience
for this distribution is mainly brazilian developers, the documentation
is provided in portuguese only. If you need any help or want to translate
it to your language, please send us some pull requests! :)

=head1 DESCRIÇÃO

Em breve!

=head1 VEJA TAMBÉM

L<Business::CPI>, L<Business::CPI::Gateway::Moip>

L<https://desenvolvedor.moip.com.br>

=head1 LICENÇA E COPYRIGHT

Copyright 2014 Breno G. de Oliveira C<< garu at cpan.org >>. Todos os direitos reservados.

Este módulo é software livre; você pode redistribuí-lo e/ou modificá-lo sob os mesmos
termos que o Perl. Veja a licença L<perlartistic> para mais informações.

=head1 DISCLAIMER

PORQUE ESTE SOFTWARE É LICENCIADO LIVRE DE QUALQUER CUSTO, NÃO HÁ GARANTIA ALGUMA
PARA ELE EM TODA A EXTENSÃO PERMITIDA PELA LEI. ESTE SOFTWARE É OFERECIDO "COMO ESTÁ"
SEM QUALQUER GARANTIA DE QUALQUER TIPO, EXPRESSA OU IMPLÍCITA. TODO O RISCO RELACIONADO
À QUALIDADE, DESEMPENHO E COMPORTAMENTO DESTE SOFTWARE É DE QUEM O UTILIZAR.
