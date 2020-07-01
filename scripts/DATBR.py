#Download all the bus routes

import os
import zipfile
import io

os.getcwd()

import requests


with(open("routes.txt","r")) as qwerty : 
    toRetList = []
    for line in qwerty:
        list = line.split(',')
        list[-1] = list[-1].strip()
        if(list[-1]!='route_short_name' and list[-1]!=''):
            toRetList.append(list[-1])

    
    for obj in toRetList:
        url = 'https://nb.translink.ca/geodata/' + obj + '.kmz'
        r = requests.get(url, allow_redirects=True)
        z = zipfile.ZipFile(io.BytesIO(r.content))
        d = z.read('doc.kml')
        open('DownloadedBusRoutes/'+obj+'.potato', 'wb').write(d)
        print('potato '+obj)
        


