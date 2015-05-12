#
# api::module.pm
#
# Copyright (c) 2011 Marko Dinic <marko@yu.net>. All rights reserved.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

package api::module;

##########################################################################################

use strict;
use warnings;

##########################################################################################

our $AUTOLOAD;

##########################################################################################

use constant {
    MAIN_PROC_DATA	=> &main::MAIN_PROC_DATA,
    CHILD_PROC_DATA	=> &main::CHILD_PROC_DATA,

    MSG_CONFIG		=> 'MSG::CONFIG',
    MSG_RECORD		=> 'MSG::RECORD',
    MSG_KEEPALIVE	=> 'MSG::KEEPALIVE'
};

##########################################################################################

#
# Internal variables
#
#  These variables are inherited by all modules.
#  Access to these variables is gained via (autogenerated)
#  accessor methods get_<variable> and set_<variable>
#
our $MOD_INITIALIZE_TIMEOUT;
our $MOD_INITIALIZE_ATTEMPTS;
our $MOD_REINITIALIZE_TIMEOUT;
our $MOD_REINITIALIZE_ATTEMPTS;
our $MOD_PROCESS_TIMEOUT;
our $MOD_PROCESS_ATTEMPTS;
our $MOD_ABORT_TIMEOUT;
our $MOD_ABORT_ATTEMPTS;
our $MOD_CLEANUP_TIMEOUT;
our $MOD_CLEANUP_ATTEMPTS;
our $MOD_HOST_TIMEOUT;
our $MOD_HOST_ATTEMPTS;

##########################################################################################
#
# Module constructor
#
#  This function is called to create a new instance
#  of the module by bless()ing module's configuration
#  hash into object of module's class. Since this is
#  a 'pure virtual' class, this method is ment to be
#  used only to instantiate module classes that inherit
#  from this one.
#
#   Input:	1. class name (passed implicitly)
#		2. hash reference to module's configuration
#
#   Output:	1. module object reference
#
sub instantiate($$) {
    my ($mod_class, $mod_confref) = @_;

    my $self = bless($mod_confref, $mod_class);

    return $self;
}
#
# Child process configurator
#
#  This method is called after OpenAC module's instance
#  has been forked into background as a separate child
#  process. This method provides the most basic instance
#  data storage space as an empty anonymous hash to modules
#  that inherit from this class. If module instance requires
#  a more specific launch-time initialization, this method
#  can be overridden by the inheriting module.
#
#   Input:	1. module instance objref (passed implicitly)
#		2+ not relevant here
#
#   Output:	1. module instance's data storage hashref
#
sub daemonize($$) {
    return {};
}
#
# Get API reference
#
#  This method retrieves and returns API base object reference
#
#   Input:	1. module instance objref (passed implicitly)
#
#   Output:	1. API base object reference
#
sub api($) {
    my $API;

    # Wrap the call inside eval to gracefully
    # catch errorneous function calls.
    eval {
	# Disable strist references locally
	no strict qw(refs);
	# Call the function inside the main context
	# to retrieve API base object reference
	$API = &{'main::__get_api'}();
    };

    return $API;
}
#
# Get communication channel
#
#  This method, if called from the main process, returns
#  communication channel to the module instance's child
#  process.
#
#  In contrast, if called from the instance's child process,
#  returns communication channel to the main process.
#
#   Input:	1. module instance objref (passed implicitly)
#
#   Output:	1. channel's file handle
#		   undef, if not open/found
#
sub channel($) {
    my $self = shift;

    if(defined($self->{CHILD_PROC_DATA})) {
	return $self->{CHILD_PROC_DATA}{'channel'};
    } elsif(defined($self->{MAIN_PROC_DATA})) {
	return $self->{MAIN_PROC_DATA}{'channel'};
    }

    return undef;
}
#
# Format config message
#
#  This method takes serialized instance configuration
#  and creates MSG_CONFIG message to be delievered to
#  the main process.
#
#   Input:	1. module instance objref (passed implicitly)
#		2. reference to an array of serialized configs
#		     or
#		2. serialized global configuration
#		3. serialized instance configuration
#
#   Output:	1. (scalar context) arrayref to MSG_CONFIG message,
#				    if configs are given as input;
#				    MSG_CONFIG type, if called
#				    without parameters.
#		   (list context) MSG_CONFIG message
#
sub config($;@) {
    shift;
#    return wantarray ? (MSG_CONFIG, @_):((@_) ? [MSG_CONFIG, @_]:MSG_CONFIG);
    # Serialized config list given as array reference ?
    if(ref($_[0]) eq 'ARRAY') {
	return wantarray ? (MSG_CONFIG, @{$_[0]}):($_[0] ? [MSG_CONFIG, @{$_[0]}]:MSG_CONFIG);
    # Serialized config list given as array
    } elsif(ref($_[0]) eq '') {
	return wantarray ? (MSG_CONFIG, @_):($_[0] ? [MSG_CONFIG, @_]:MSG_CONFIG);
    }
    return wantarray ? ():undef;
}
#
# Format and deliver config message
#
#  This method takes serialized instance configuration,
#  creates MSG_CONFIG message and then delivers it to
#  the main process.
#
#   Input:	1. module instance objref (passed implicitly)
#		2. serialized global configuration
#		3. serialized instance configuration
#		4. communication channel (optional)
#
#   Output:	nothing
#
sub put_config($$$;$) {
    my ($self, $globalcfg, $instcfg, $fh) = @_;

    $self->api->put_args(defined($fh) ? $fh:$self->channel,
			 scalar($self->config($globalcfg, $instcfg)));
}
#
# Verify if message is MSG_CONFIG
#
#   Input:	1. module instance objref (passed implicitly)
#		2. message
#
#   Output:	1. TRUE, if message is MSG_CONFIG
#		   FALSE, if not
#
sub is_config($$) {
    shift;
    return (defined($_[0]) && $_[0] eq MSG_CONFIG) ? 1:0;
}
#
# Format record data message
#
#  This method takes an arbritary number of arguments
#  and creates MSG_RECORD message to be delievered to
#  the main process.
#
#   Input:	1. module instance objref (passed implicitly)
#		2. reference to data record array
#		   or data record array directly
#
#   Output:	1. (scalar context) arrayref to MSG_RECORD message
#				    if data is given as input;
#				    MSG_RECORD type, if called
#				    without parameters.
#		   (list context)   MSG_RECORD message
#
sub record($;@) {
    shift;

    # Record data given as array reference ?
    if(ref($_[0]) eq 'ARRAY') {
	return wantarray ? (MSG_RECORD, @{$_[0]}):($_[0] ? [MSG_RECORD, @{$_[0]}]:MSG_RECORD);
    # Record data given as array
    } elsif(ref($_[0]) eq '') {
	return wantarray ? (MSG_RECORD, @_):($_[0] ? [MSG_RECORD, @_]:MSG_RECORD);
    }
    return wantarray ? ():undef;
}
#
# Format and deliver record data message
#
#  This method takes an arbritary number of arguments
#  creates MSG_RECORD message and then delivers it to
#  the main process. Unless explicitly defined, default
#  child process's communication channel is used.
#
#
#   Input:	1. module instance objref (passed implicitly)
#		2. arrayref to data record to be delivered
#		3. communication channel (optional)
#
#   Output:	nothing
#
sub put_record($$;$) {
    my ($self, $record, $fh) = @_;
#    unshift @{$record}, $self->record;
    $self->api->put_args(defined($fh) ? $fh:$self->channel,
			 scalar($self->record($record)));
}
#
# Verify if message is MSG_RECORD
#
#   Input:	1. module instance objref (passed implicitly)
#		2. message
#
#   Output:	1. TRUE, if message is MSG_RECORD
#		   FALSE, if not
#
sub is_record($$) {
    shift;
    return (defined($_[0]) && $_[0] eq MSG_RECORD) ? 1:0;
}
#
# Format keepalive message
#
#  This method creates MSG_KEEPALIVE message to be delievered
#  to the main process.
#
#   Input:	1. module instance objref (passed implicitly)
#
#   Output:	1. (scalar context) MSG_KEEPALIVE type
#		   (list context) MSG_KEEPALIVE message
#
sub keepalive($) {
    return wantarray ? (MSG_KEEPALIVE):MSG_KEEPALIVE;
}
#
# Format and deliver keepalive message
#
#  This method creates MSG_RECORD message and delivers 
#  it to the main process. Unless explicitly defined,
#  default child process's communication channel is used.
#
#   Input:	1. module instance objref (passed implicitly)
#		2. communication channel (optional)
#
#   Output:	nothing
#
sub put_keepalive($;$) {
    my ($self, $fh) = @_;
    $self->api->put_args(defined($fh) ? $fh:$self->channel,
			 $self->keepalive);
}
#
# Verify if message is MSG_KEEPALIVE
#
#   Input:	1. module instance objref (passed implicitly)
#		2. message
#
#   Output:	1. TRUE, if status is MSG_KEEPALIVE
#		   FALSE, if not
#
sub is_keepalive($$) {
    shift;
    return (defined($_[0]) && $_[0] eq MSG_KEEPALIVE) ? 1:0;
}
#
# Autogenerate accessor methods
#
#  Purpose of this function is to provide modules
#  the clean way of accessing private object variables.
#  After creating an instance of a module inheriting
#  from api::module, any
#
#       $instance->get_<variable>,
#       $instance->set_<variable>(<value>)
#       $instance->put_<variable>(<values>)
#       $instance->push_<variable>(<value>)
#       $instance->pop_<variable>
#       $instance->unshift_<variable>(<value>)
#       $instance->shift_<variable>
#
#  call that is not explicitly implemented within module
#  will be served by this method.
#
sub AUTOLOAD {
    my $self = shift;

    # Unqualify function name
    my ($op, $var) = ($AUTOLOAD =~ /^(?:.*::)?([^\_]+)\_([^:]+)/);

    if(defined($op) && $op ne "" && defined($var) && $var ne "") {

	no strict;

	# Retrieve value ?
	if($op eq 'get') {
	    return wantarray ?
		    (eval '@MOD_'.uc($var)):
		    eval '$MOD_'.uc($var);
	# Set scalar value ?
	} elsif($op eq 'set') {
	    eval '($MOD_'.uc($var).')=@_';
	# Set array ?
	} elsif($op eq 'put') {
	    eval '@MOD_'.uc($var).'=@_';
	# Push a single value into the array ?
	} elsif($op eq 'push') {
	    eval 'push @MOD_'.uc($var).',$_[0]';
	# Pop a single value from the array ?
	} elsif($op eq 'pop') {
	    return eval 'pop @MOD_'.uc($var);
	# Unshift a single value into the array ?
	} elsif($op eq 'unshift') {
	    eval 'unshift @MOD_'.uc($var).',$_[0]';
	# Shift a single value from the array ?
	} elsif($op eq 'shift') {
	    return eval 'shift @MOD_'.uc($var);
	# Unsupported operation
	} else {
	    $self->api->logging('LOG_ERR', "Invalid function %s called by %s",
					   $AUTOLOAD,
					   caller());
	    return undef;
	}

	return;

    }

    $self->api->logging('LOG_ERR', "Function %s called by %s is not defined by module API",
				   $AUTOLOAD,
				   caller());

    return undef;
}
#
# Default module destructor
#
sub DESTROY {
}

1;
