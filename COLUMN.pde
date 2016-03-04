/*

  raw from master node 
  
  01xxxxyyyyzzzzffff02 ...
  
  stored to strArray

*/

int GetByte(){
  while (!Serial1.available());
  return Serial1.read();
}

char *GetColumnData(char *data){
	int buf = 0;
	int buf_prev = 0;
	boolean sample_end = false;
	int r = 0;
	int z = 0;
	int t = 0;
	int i,j=0;
	int timeout1 = 0;
	int timeout2 = 0;

	Serial.print("Getting column data .");

	for(r=0; r<10; r++){
		Serial1.flush();
		delay(2000);
		int Savailable = 50;
		if(Serial1.available()){
			do{
				z = GetByte();
				Serial.print("*");
				Savailable--;
				delay(1);
				//Serial.println(z, HEX);
			}while ((z != 0xAA)&&(Savailable > 0));

			// clear 0xAA byte      
			buf = GetByte();
		  
			// get all the data first before processing
			t = 0;
			//buf = GetByte();
			sample_end = false;
			do{
				/*
				sprintf(&data[t], "%02X", buf);
				t = t + 2;
				buf = GetByte();  
				*/
				buf = GetByte();  
				if (buf_prev == 0xBB && buf == 0xBB){
					sample_end = true;
				}
				else{
					sprintf(&data[t], "%02X", buf);
					t = t + 2;
					buf_prev = buf;
					//Serial.print(buf,HEX);
				}   
			}while   (!sample_end);
		  
			 //Serial.println(data);
		      
                  
		  // cleaning the data
		  // remove characters that have indeces of 2, 6 and 10 within 
		  // a node data line
		  // i.e.
		  //     nnxxxxyyyyzzzzffff
		  //       2   4   A
		  //
		  // method is to get the modulo of index to 18, add 2 so that
		  // indeces would be 4, 8 and 12 which are divisible by 4
		  // and exclude original index 14 which is the msb of soil
		  // moisture frequency reading      
			for (i=0, j=0; data[i]!='\0'; i++, j++){
				if(((i%18)+2)%4==0 && (i%18)!=14) i++;
					data[j] = data[i];
			}
                        data[j] = '\0';
			// Serial.println(data);
			break;
		}
		else{
			Serial.print(".");
			delay(500);
		}
	} 
	if (r>9) Serial.println("ERROR");
	else Serial.println("done");
  
	return data;
}

char *concatColumnData(char *columnData, char *tempData){
  int i=0;
  int j=0;
  int skipFlag = 2;
  int y = 15;//length of a string of data for a single node ID
  int copy = 0;
  Serial.println("\nparsing column data...");
  
  if(columnData != NULL){//remove BB
    for(int k=0;k<2;k++){
      columnData[strlen(columnData)-1] = '\0';
    }
  }
  
  for(i=0; i < strlen(tempData); i += 15){  //loop through tempData and increment by the 
    copy = 1;
    j=0;
    /*
    Serial.print("Checking from temp node #: ");
    Serial.print(tempData[i]);
    Serial.print(tempData[i+1]);
    
    Serial.print("\tstrlen of tempData: ");
    Serial.print(strlen(tempData));
    
    Serial.print("\ti = ");
    Serial.println(i);
    */
    if((tempData[i+2] == NULL) && (i!=0)) break;//break out of loop when BB is reached in tempData and when i is != 0
    while(j < strlen(columnData)){
      /*
      Serial.print("\tcomparing to: ");
      Serial.print(columnData[j]);
      Serial.print(columnData[j+1]);
      
      Serial.print("\tstrlen of columnData: ");
      Serial.println(strlen(columnData));
      */
      if(tempData[i] == columnData[j]){//decrement skipFlag if the same
        copy = 0;
        skipFlag--;
        i++;
        j++;
      }
      else{//else, decrement k to the 1st digit of the node ID
        copy = 1;
        i -= (2 - skipFlag);//balik sa normal si i
        j += (y + (skipFlag - 2));//move to next node id
        skipFlag = 2;
      }
      
      if(skipFlag == 0){//if both digits match...
        copy = 0;
        i-=2;
        //i += y-2;
        j += y-2;
        skipFlag = 2;
        //Serial.println("breaking now...");
        break;
      }
      
    }//end of j-loop 
    
    if(copy == 1){
      int len = strlen(columnData);
      int k;
      for(k=0; k<y; k++){
          columnData[len+k] = tempData[i-(2-skipFlag)];
          i++;
      }
      i-=k;//change i back to its value before being incremented by the code inside the loop
    }
    
  }//end of i-loop
  Serial.println("done parsing\n");
}//end of function concatColumnData


/*
Separate piezo data from colum data
parses tempdata to get the last node
and puts it in a separate string

march 2016 update: includes thermistor temp in the parsing

*/

void getPiezoData(char *scratchdata, char* piezodata){
  int piezo_present = 0;
  int i = 0;
  int location;
  int piezolen = 20;
  int k,l;
  int m;
  char removed[700]; //for removed data
  
  //assume piezo node greater than other nodes
  //find piezo node in tempdata
    for(i==0; i < strlen(scratchdata); i+=15){
      
      if((scratchdata[i] == PIEZOID[0]) && (scratchdata[i+1] == PIEZOID[1])){
          location = i;
          piezo_present = 1;
          Serial.println();
          Serial.println("Piezo node found");
          break;
          
        }
    }
    
    if(piezo_present){
            
          /*found location, transfer to separate string variable*/
          for(m=0; m < piezolen ; m++){
          piezodata[m] = scratchdata[location+m]; 
          }
         
         //clean piezo sensor data, remove excess data
         for (k=0,l=0;l  <= piezolen; l++,k++){
             if(((k+1) % 3 == 0) && (k < 9)) k++;
             piezodata[l] = piezodata[k];
         }
           piezodata[12] = '\0';
//           Serial.println("PIEZODATA");
//            Serial.println(piezodata);
//            Serial.println();
          int removeStart = location+15;
          int removeLen = strlen(scratchdata)-removeStart;
          int removeEnd = removeLen; //BBis here
          
          //remove sobrang strings
          for(m=0; m <= removeLen;m++){
            removed[m] = scratchdata[m+removeStart];
              //remove bb, 2nd to the last data
              if(m == removeEnd){
                removed[m] = '\0';
                Serial.println("removed data");
                Serial.println(removed);
              }
            }
            
            //cut data
            scratchdata[location] = '\0';
           
           //put all sensor data in one string
           strcat(scratchdata,removed);
           
//            Serial.println("DATA cat");
//            Serial.println(tempdata);
//            Serial.println();    
        }
        
        
    else{
      Serial.println("Piezo Node Disconnected");
      piezodata[0] = '\0';
    }
   
}



