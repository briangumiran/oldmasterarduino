void makeFilename(char *filename, int counter){
  String temp= "A" + String(counter) + "." + "txt";
  temp.toCharArray(filename, 8);
}

void storeData(char *data, int counter){

  char *filename="";
  filename = (char *) calloc(8, sizeof(char *));

  makeFilename(filename, counter);
  
  strncat(data, "!", 1);

  File dataFile = SD.open(filename, FILE_WRITE);
  Serial.print("\nfilename: ");
  Serial.print(filename);
  Serial.print("\ndata: ");
  Serial.println(data);
  if (dataFile) {
    Serial.print("1");
    dataFile.println(data);
    Serial.print("2");
    dataFile.close();
    Serial.println("3");
  }  
  Serial.println("before free");
  free(filename);
  Serial.println("after free");
}

void logData(String temp= "", String data=""){

  char filename[12];
  temp.toCharArray(filename, sizeof(filename));

  char dataLog[160];
  data.toCharArray(dataLog, sizeof(dataLog));

  Serial.print("\nfilename: ");
  Serial.println(filename);
  Serial.print("data: ");
  Serial.println(data);

  File dataFile = SD.open(filename, FILE_WRITE);
  if (dataFile) {
    Serial.print("1");
    dataFile.print(dataLog);
    Serial.print("2");
    dataFile.close();
    Serial.println("3");
  }
  Serial.println("EXITING");
}

int sendDataFromFile(int counter){
  int ret= 0;
  char *filename="";
  filename = (char *) calloc(8, sizeof(char *));
  
  makeFilename(filename, counter);
  
  if (SD.exists(filename)) {
    File dataFile = SD.open(filename);
    if (dataFile) {
      int j=0;
      int i=0;
      String unsentData[12]={};
      char tempData[180]= {};

      while (dataFile.available()) {
        char recChar= (char)dataFile.read();
        
        if (recChar !='\n' && recChar != '\r' ){
          tempData[i] = recChar;
          i++;  
        }

        if (tempData[i-1] == '!'){
          tempData[i-1]='\0';
          if ((SendMsg(MOBILENUM, tempData, buffer)) == 1){
            unsentData[j]= tempData;
            j++;
            delay(1000);
          }
          i=0;
          tempData[0] = '\0'; // CLEAR DATA
        }
      }
      tempData[0] = '\0'; // CLEAR DATA
      dataFile.close();
      SD.remove(filename);
      free(filename);
      int k= j;

      if (j > 0){
        for (j=0; j < k; j++){
          Serial.print("savingNewFile: ");
          Serial.println(&unsentData[j][0]);
          storeData(&unsentData[j][0], counter);
          delay(1000);
        }
      }
   unsentData[0] = '\0';
      j=0;
    }  
    else {
      Serial.println("error opening datalog.txt");
    }        
  }
  else {
    Serial.println("OUTBOX.txt doesn't exist.");
  }  
  return 0;
}

int checkOutboxFiles(){
  int counter= 0;
  int numFile=counter;
  
  char *filename="";
  
  filename = (char *) calloc(8, sizeof(char *));
  makeFilename(filename, counter);
  while (SD.exists(filename)) {
    File dataFile = SD.open(filename);
    int j=0;     

    if (dataFile) {

      while (dataFile.available()) {
        char h= (char)dataFile.read(); 
        if ( h == '!'){
          j++;
        }//if
      }//while

      if (j>= 8) {
        numFile= counter + 1;
      }
      else numFile= counter;
      
      counter++;  
      dataFile.close();
      makeFilename(filename, counter);
    }

    else {
        Serial.println("error opening datalog.txt");
      }
    delay(500);
    
  }
  free(filename);
  return numFile; 
}
