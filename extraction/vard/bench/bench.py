import time
import argparse
import random
import threading
import etcd
import vard

t = threading

gets = []
puts = []
DEBUG = False

def benchmark(ev, client, requests, keys, put_percentage, n):
    random.seed(n)
    put_prob = put_percentage / 100.0
    ev.wait()
    for i in range(requests):
        key = str(random.randint(0, keys))
        if random.random() < put_prob:
            start = time.time()
            client.put('key' + key, str(i))
            end = time.time()
            puts.append(end-start)
        else:
            start = time.time()
            client.get('key' + key)
            end = time.time()
            gets.append(end-start)
        if DEBUG:
            print 'Thread %d Done with %d requests' % (n, i)

def cluster(addrs):
    ret = []
    for addr in addrs.split(','):
        (host, _, port) = addr.partition(':')
        ret.append((host, int(port)))
    return ret

def main():
    global DEBUG
    parser = argparse.ArgumentParser()
    parser.add_argument('--service', default='vard', choices=['etcd', 'vard'])
    parser.add_argument('--cluster', type=cluster, required=True)
    parser.add_argument('--requests', default=1000, type=int)
    parser.add_argument('--threads', default=50, type=int)
    parser.add_argument('--keys', default=100, type=int)
    parser.add_argument('--put-percentage', default=50, type=int)
    parser.add_argument('--debug', default=False, action='store_true')
    args = parser.parse_args()

    if args.debug:
        DEBUG = True
    Client = vard.Client
    if args.service == 'etcd':
        Client = etcd.Client

    host, port = Client.find_leader(args.cluster)
    ev = t.Event()
    threads = []
    for i in range(args.threads):
        c = Client(host, port)
        thr = t.Thread(target=benchmark, args=(ev, c, args.requests, args.keys, args.put_percentage, i))
        threads.append(thr)
        thr.start()
    start = time.time()
    ev.set()
    for thr in threads:
        thr.join()
    end = time.time()
    print 'Total time: %f' % (end - start)
    print '%f gets, avg = %f' % (len(gets), sum(gets)/len(gets))
    print '%f puts, avg = %f' % (len(puts), sum(puts)/len(puts))
    
        
if __name__ == '__main__':
    main()
