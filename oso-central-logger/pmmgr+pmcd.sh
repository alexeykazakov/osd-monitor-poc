#! /bin/sh

# Initialize a little unprivileged pcp pmcd metrics collector
# process within this container; run this in a background subshell.
# No special signal handling or cleanup required.
(
# Setup pmcd to run in unprivileged mode of operation
. /etc/pcp.conf

PATH=$PATH:$PCP_BINADM_DIR
export PATH

# Configure pmcd with a minimal set of DSO agents
rm -f $PCP_PMCDCONF_PATH; # start empty
echo "# Name  ID  IPC  IPC Params  File/Cmd" >> $PCP_PMCDCONF_PATH;
echo "pmcd     2  dso  pmcd_init   $PCP_PMDAS_DIR/pmcd/pmda_pmcd.so"   >> $PCP_PMCDCONF_PATH;
echo "proc     3  dso  proc_init   $PCP_PMDAS_DIR/proc/pmda_proc.so"   >> $PCP_PMCDCONF_PATH;
echo "linux   60  dso  linux_init  $PCP_PMDAS_DIR/linux/pmda_linux.so" >> $PCP_PMCDCONF_PATH;
echo "prometheus 144 pipe binary python $PCP_PMDAS_DIR/prometheus/pmdaprometheus.python -l -" >> $PCP_PMCDCONF_PATH;
rm -f $PCP_VAR_DIR/pmns/root_xfs $PCP_VAR_DIR/pmns/root_jbd2 $PCP_VAR_DIR/pmns/root_root $PCP_VAR_DIR/pmns/root
echo 'prometheus	144:*:*' > $PCP_VAR_DIR/pmns/prometheus
touch $PCP_VAR_DIR/pmns/.NeedRebuild

# allow unauthenticated access to proc.* metrics (default is false)
export PROC_ACCESS=1
export PMCD_ROOT_AGENT=0

# NB: we can't use the rc.pmcd script.  It assumes that it's run as root.
# NB: we can't run the pmda Install scripts.  They assume ping etc. are available.
cd $PCP_VAR_DIR/pmns
./Rebuild
pmnsadd -n root prometheus

cd $PCP_LOG_DIR

: "${PCP_HOSTNAME:=`hostname`}"
# possibly: filter pod name?
exec /usr/libexec/pcp/bin/pmcd -l - -f -A -H $PCP_HOSTNAME
) &
sleep 5 # give time for pmcd's startup messages, so it doesn't intermix with pmmgr's

# XXX: loop regenerating the tenant list, regenerating pmmgr
(. /etc/pcp.env;
 while true
 do
     sh /regen-tenant-list.sh
     sleep 60
 done) &
    
exec $VALGRIND /usr/libexec/pcp/bin/pmmgr -v -v -p 180 -c /etc/pcp/pmmgr-tenants
# XXX: one pmmgr configuration directory per tenant-class
