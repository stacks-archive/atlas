#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
    Atlas-monitor
    ~~~~~

    This file is part of Atlas-monitor.

    Blockstack-client is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Atlas-monitor is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.
    You should have received a copy of the GNU General Public License
    along with Blockstack-client.  If not, see <http://www.gnu.org/licenses/>.
"""

import os
import sys
import time
import socket
import sqlite3
import geocoder
import json
import pycountry
from Queue import Queue
from PIL import Image

import blockstack_client

from constants import *

class SetQueue(Queue):

    def _init(self, maxsize):
        Queue._init(self, maxsize) 
        self.all_items = set()
    def _put(self, item):

        if item not in self.all_items:
            Queue._put(self, item) 
            self.all_items.add(item)

def bitcount( bitvec, status, filename=None ):
    count = 0
    if status:
        img = Image.new( 'RGBA', (IMG_WIDTH,int((len(bitvec)*8)/IMG_WIDTH*1.1)),'black')
        pixels = img.load()
    for i in xrange(0, len(bitvec)):
        bitfield = ord(bitvec[i])
        for j in xrange(0, 8):
            if status:
                # check set
                if ((1 << (7-j)) & bitfield) != 0:
                    count += 1
                    img.putpixel(((i*8+j)%IMG_WIDTH,(i*8+j)/IMG_WIDTH),(230,230,230))
                else:
                    img.putpixel(((i*8+j)%IMG_WIDTH,(i*8+j)/IMG_WIDTH),(255,30,99))
            else:
                # check unset 
                if ((1 << (7-j)) & bitfield) == 0:
                    count += 1
    if status:
        img.save(WWW_DIR+'/media/'+filename+'.png', 'PNG')
    return count

def createTables(db):
    cursor = db.execute('DROP TABLE IF EXISTS hosts')
    sql = """
    CREATE TABLE hosts(
        hostname text,
        lat text,
        lng text,
        city text,
        state text,
        country text,
        lastblock int,
        present int,
        absent int,
        ts int) 
    """
    cursor.execute(sql)
    db.commit()

    cursor = db.execute('DROP TABLE IF EXISTS links')
    sql = """
    CREATE TABLE links(
        source text,
        target text,
        ts int,
        UNIQUE(source, target) ON CONFLICT REPLACE ) 
    """
    cursor.execute(sql)
    db.commit()

    addPeer(ORIGIN_HOST, db)

def url_to_ip_port(hostport):
    host, port = blockstack_client.config.url_to_host_port(hostport)
    try:
        socket.inet_aton(str(host))
    except socket.error:
        host = socket.gethostbyname(host)
    return [host,port]

def addPeer(hostport, db):
    ip, port = url_to_ip_port( hostport )
    ipport = ip+':'+str(port)
    if ip not in ['127.0.0.1', '::1']:
        cursor = db.execute('''SELECT hostname FROM hosts WHERE hostname = ?''',(ipport,))
        if not len(cursor.fetchall()):
            g = geocoder.ip(ip)
            country = pycountry.countries.get(alpha_2=g.country)
            cursor = db.execute('''INSERT INTO hosts(hostname, lat, lng, city, state, country) VALUES(?,?,?,?,?,?)''',(ipport, g.lat, g.lng, g.city, g.state, country.name))
            db.commit()   

def addLink(source,target,db):
    s_ip, s_port = url_to_ip_port( source )
    s_ipport = s_ip+':'+str(s_port)
    t_ip, t_port = url_to_ip_port( target )
    t_ipport = t_ip+':'+str(t_port)
    cursor = db.execute('''INSERT INTO links(source, target, ts) VALUES(?,?,?)''',(s_ipport, t_ipport, time.time()))

def outputJson(db):
    cursor = db.execute("""select * from hosts""")
    rows = cursor.fetchall()
    nodes = [];n={};counter = 0;
    for row in rows:
        if row[0]!='localhost:6264':
            item = {'host': row[0],
                    'latitude': row[1],  
                    'longitude': row[2],
                    'city': row[3],
                    'state': row[4],
                    'country': row[5],
                    'lastblock': row[6],
                    'present': row[7],
                    'absent': row[8],
                    'ts': row[9],
                    'radius': 3,
                    'fillKey': 'BB'}
            nodes.append(item)
            n[row[0]]=counter;counter=counter+1

    cursor = db.execute("""select * from links""")
    rows = cursor.fetchall()
    links = []
    for row in rows:
        if row[0]!='127.0.0.1:6264' and row[1]!='127.0.0.1:6264':
            item = {'source': n[row[0]],
                    'target': n[row[1]],  
                    }
            links.append(item)

    data = {'updated': time.time(), 'nodes':nodes, 'links':links}
    with open(WWW_DIR+'/json/diagnostic.json', 'w') as outfile:
        json.dump(data, outfile)

def main( argv ):
    hostport_list = []
    atlas_info = {}

    db = sqlite3.connect(ATLAS_MONITOR_DB)

    if len(sys.argv) == 2 and argv[1]=='initdb':
        createTables(db)

    cursor = db.execute('''SELECT hostname FROM hosts''')
    rows = cursor.fetchall()

    q = SetQueue()
    [q.put(i[0]) for i in rows]
 
    while not q.empty():
        hostport = q.get(block = False)
        print 'Contact {}'.format(hostport)
        resp = blockstack_client.proxy.get_zonefile_inventory( hostport, 0, 52880 * 8 )
        if 'error' in resp:
            print 'Failed to contact {}: {}'.format(hostport, resp['error'])
        else:
            atlas_info[hostport] = resp
            peers = blockstack_client.proxy.get_atlas_peers(hostport)
            for peer in peers['peers']:
                addLink(hostport,peer,db)
                if peer not in q.all_items:
                    q.put(peer)
                    addPeer(peer, db)

    for hostport, atlas_inv in atlas_info.items():
        present = bitcount( atlas_inv['inv'], 1 , url_to_ip_port( hostport )[0])
        absent = bitcount( atlas_inv['inv'], 0 )
        db.execute('''UPDATE hosts SET lastblock = ?, present = ?, absent = ?, ts = ? WHERE hostname = ?''',(atlas_inv['lastblock'], present, absent, time.time(),hostport,))
        db.commit()
        print '{}: {} bytes, {} present, {} absent'.format(hostport, len(atlas_inv['inv']), present, absent)

    outputJson(db)
    db.close()

if __name__ == '__main__':

    main( sys.argv )