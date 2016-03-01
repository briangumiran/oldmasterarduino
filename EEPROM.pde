void eepromCHECK(){
  int adr=0, choice=0, len=0;
  int data=0;
  byte data2 = NULL;

  while(1){  
    Serial.print("\n\n[0] Write\n[1] Read\n[2] Clear\n[3] Break\nEnter choice: ");
    while(!Serial.available()){}
    if(Serial.available()){
      choice = readAsInt();
      Serial.println(choice);
    }
    
    if(choice==0){
      Serial.print("Input address number (0-511): ");
      while(!Serial.available()){}
      if(Serial.available()){
        adr = readAsInt();
        Serial.println(adr);
      }
      
      if((adr >= 5) && (adr <= 6)){//Enter integer to addr 5-6
      //if(adr == 5){// Enter integer to addr 5
          Serial.print("Input data: ");
          while(!Serial.available()){}
          if (Serial.available()){
            data = readAsInt();
            Serial.println(data);
            EEPROM.write(adr,data);
          }
      }
      else{// Enter data to an adr to adr+len-1 as bytes
        Serial.print("Input string length: ");
        while(!Serial.available()){}
        if(Serial.available()){
          len = readAsInt();
          Serial.println(len); 
        }
        Serial.print("Input data: ");
        for(int i=0;i<len;i++){
          while(!Serial.available()){}
          if (Serial.available()){
            data2 = Serial.read();
            Serial.print(data2);
            EEPROM.write(adr+i,data2);
          }
        }//end of for
        Serial.println();
      }//end of if-else
  }//end of choice 0
  
    else if(choice == 1){
      Serial.print("Input address number (0-511): ");
      while(!Serial.available()){}
      
      if(Serial.available()){
        adr = readAsInt();
        Serial.println(adr);
      }
      
      if((adr >= 5) && (adr <= 6)){//Enter integer to addr 5-6
      //if( adr == 5){  //if selected adr = 5, treat data as integer
        Serial.print("Data at address ");
        Serial.print(adr);
        Serial.print(" is ");
        Serial.println((int)EEPROM.read(adr));
      }
      else{  //  else, ask for string length and treat all data from adr to adr+len-1 as bytes
        Serial.print("Input string length: ");
        while(!Serial.available()){}
        
        if(Serial.available()){
          len = readAsInt();
          Serial.println(len);
        } 
        
        eepromCmdRead(adr,len);
        
      }
    }
  
    else if(choice == 2){
      for (int i = 0; i < 512; i++) EEPROM.write(i, 255); 
      Serial.println("EEPROM cleared");
    }
    
    else if(choice == 3) break;
    
    else  Serial.println("Invalid input");

    delay(200);
  }
}

void eepromCmdWrite(int add, int len, char*buffer){
    for(int i=0; i<len; i++){
      EEPROM.write(add+i,buffer[i]); 
    }
    Serial.print("Writing: ");
    Serial.println(buffer);
}

void eepromCmdRead(int add, int len){
  Serial.print("Reading: ");
  for(int i=0; i<len; i++)  Serial.print(EEPROM.read(add+i));
  Serial.println();
}

int eepromCheckNull(int add,int len){
    for(int i=0;i<len;i++){
       if(EEPROM.read(add+i)==NULL) return 0;
       if(EEPROM.read(add+i)==255) return 0; //default value
    }
    return 1;
}

int readAsInt(){
  int x;
  int a=0;
  int i=0;
  
  while(Serial.available()){
      x = Serial.read();
      if(x>47 && x <59){
          x-=48; 
          a = a*10 + x;
      }
      else return a=255;
      i++;
      delay(1);
  }
  return a;
}
