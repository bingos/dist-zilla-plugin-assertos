package Dist::Zilla::Plugin::AssertOS;

# ABSTRACT: Require that our distribution is running on a particular OS

use Moose;
with 'Dist::Zilla::Role::FileGatherer';
with 'Dist::Zilla::Role::InstallTool';
with 'Dist::Zilla::Role::MetaProvider';

use File::Spec;

sub mvp_multivalue_args { qw/os/ }

has 'os' => (
    is      => 'ro',
    isa     => 'ArrayRef',
    default => sub { [] },
    auto_deref => 1,
);

sub metadata {
  return {
    no_index => {
      directory => [ 'inc' ],
    }
  };
}

sub gather_files {
  my $self = shift;
  
  require Data::Compare;

  foreach my $os ( $self->os ) {
    my $oldinc = { map { $_ => $INC{$_} } keys %INC }; # clone
    eval "use Devel::AssertOS qw($os)";
    if(Data::Compare::Compare(\%INC, $oldinc)) {
        print STDERR "Couldn't find a module for $os\n";
        exit(1);
    }
  }

  my @modulefiles = keys %{{map { $_ => $INC{$_} } grep { /Devel/i && /(Check|Assert)OS/i } keys %INC}};

  foreach my $modulefile (@modulefiles) {
    my $fullfilename = '';
    SEARCHINC: foreach (@INC) {
        if(-e File::Spec->catfile($_, $modulefile)) {
            $fullfilename = File::Spec->catfile($_, $modulefile);
            last SEARCHINC;
        }
    }
    die("Can't find a file for $modulefile\n") unless(-e $fullfilename);

    (my $module = join('::', split(/\W+/, $modulefile))) =~ s/::pm/.pm/;
    my @dircomponents = ('inc', (split(/::/, $module)));
    my $file = pop @dircomponents;

    { 
      open(my $PM, $fullfilename) ||
        die("Can't read $fullfilename: $!");
      local $/ = undef;
      (my $content = <$PM>) =~ s/package Devel::/package #\nDevel::/;
      close($PM);
      
      my $pm = Dist::Zilla::File::InMemory->new({
         content => $content,
         name    => File::Spec->catfile(@dircomponents, $file),
      });

      $self->add_file($pm);

    }
  }
  return;
}

# XXX - this should really be a separate phase that runs after InstallTool -
# until then, all we can do is die if we are run too soon
sub setup_installer {
  my $self = shift;

  my @mfpl = grep { $_->name eq 'Makefile.PL' or $_->name eq 'Build.PL' } @{ $self->zilla->files };

  $self->log_fatal('No Makefile.PL or Build.PL was found. [AssertOS] should appear in dist.ini after [MakeMaker] or [ModuleBuild]!') unless @mfpl;

  for my $mfpl ( @mfpl ) {
    my $content = qq{use lib 'inc';\nuse Devel::AssertOS qw[};
    $content .= join ' ', $self->os;
    $content .= "];\n";
    $mfpl->content( $content . $mfpl->content );
  }
  return;
}

__PACKAGE__->meta->make_immutable;
no Moose;

qq[run run Reynard];

=pod

=head1 SYNOPSIS

  # In dist.ini - It is important that AssertOS follows MakeMaker or
  # ModuleBuild

  [MakeMaker]

  [AssertOS]
  os = Linux
  os = FreeBSD
  os = cygwin

The resultant distribution will die at C<Makefile.PL> unless the platform the code is running on is Linux, FreeBSD or Cygwin.

=head1 DESCRIPTION

Dist::Zilla::Plugin::AssertOS is a L<Dist::Zilla> plugin that integrates L<Devel::AssertOS> so that CPAN authors
may easily stipulate which particular OS environments their distributions may be built and installed on.

The author specifies which OS or OS families are supported. The necessary L<Devel::AssertOS> files are copied to the 
C<inc/> directory and C<Makefile.PL> or C<Build.PL> is mungled to include the necessary incantation.

On the module user side, the bundled C<inc/> L<Devel::AssertOS> determines whether the current environment is 
supported or not and will die accordingly.

As this plugin mungles the C<Makefile.PL>/C<Build.PL> it is imperative that it is specified in C<dist.ini> 
AFTER C<[MakeMaker]> or C<[ModuleBuild]>.

This plugin also automagically adds the C<no_index> metadata so that C<inc/> is excluded from PAUSE indexing. If 
you use L<Dist::Zilla::Plugin::MetaNoIndex>, there may be conflicts.

=head2 ATTRIBUTES

=over

=item C<os>

Specify as many times as wanted the OS that you wish your distribution to work with. See L<Devel::AssertOS> and
L<Devel::CheckOS> for what may be given.

=back

=head2 METHODS

These are required by the roles that this plugin uses.

=over

=item C<mvp_multivalue_args>

=item C<gather_files>

Required by L<Dist::Zilla::Role::FileGatherer>.

=item C<setup_installer>

Required by L<Dist::Zilla::Role::InstallTool>.

=item C<metadata>

Required by L<Dist::Zilla::Role::MetaProvider>.

=back

=head1 KUDOS

Based on L<use-devel-assertos> by David Cantrell

Build.PL support contributed by Yanick Champoux

Thanks to Ricardo Signes, not only for L<Dist::Zilla>, but for explaining L<Dist::Zilla::Role::InstallTool>'s
place in the build process. This made this plugin possible.

=head1 SEE ALSO

L<Dist::Zilla>

L<Devel::AssertOS>

L<Devel::CheckOS>

=cut
