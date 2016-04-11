#include <avr/power.h>
#include <avr/sleep.h>
#include <avr/eeprom.h>
//MMC
#include <SD.h>
#include <EEPROM.h>
#include <SPI.h>
#define BUILDNUMBER "030416"
// 030416 - piezo thermisor
// 110415 - piezo code integration
// 091714 - implemented SDcard with power switch and level shifter
// 082214 - Bug fix - code (gets stuck in infinite while-loop when attempting to toggle GSM when power is low. Added SD/voltage monitoring shield. Added status report message.
// 050714 - added function that concatenates broken column data together when retryVal is greater than 1.
// 032614 - added else statements to getCsq and SimAvailable functions. Code (used to) possibly hangs if GSM responds with an error.
// 031514 - added safety toggle for GSM power toggle
// 121513 - removed CNMI from default AT commands at initGSM
// 112913 - Bug fixes. Added catch to GSM response "ERROR"
// 100413 - added SD, GSM and EEPROM control functionsMM
// 071813 - changed timeout of sending data in GSM.pde
// 071813-B - added global time check after gsm operations
//#define MASTERNAME "PUGB"
//#define SERVERNUM "09094427156"	// SMART
//#define MOBILENUM "09395834481"	// SMART
//#define SERVERNUM "09227321596"	// SUN
//#define MOBILENUM "09236382723"	// SUN
//#define SERVERNUM "09176321023"	// GLOBE
//#define MOBILENUM "09162408795"	// GLOBE


#define CMDKEY "*#CMD#*"

#define CLEAR 1  // clear buffer after query
#define SAVE  0  // save buffer after query
#define OFF 1  // stat pin is HIGH (1) so it needs to be turn off
#define ON  0  // stat pin is LOW (0) so it needs to be turn on
//#define REPORTINTERVAL 30  // report interval in minutes
#define RELAYPIN 26
#define STATPIN 6
#define TURN_COLUMN_ON digitalWrite(RELAYPIN, HIGH);
#define TURN_COLUMN_OFF digitalWrite(RELAYPIN, LOW);
#define SAVEMSG false
#define DELMSG true
#define simCheck 1
#define signalCheck 1
#define WITHPIEZO 1

//Voltage monitor variables
#define analogPin A7
#define ResConstant 0.3255
#define voltSwitch 3
#define batLineRead 2

//MMC
#define MMCPIN 53
#define MMCON 10
#define MMCEN 9


int counter= 0;
int sending=0;
int sendC=0;
int sendFlag=0; //0 kapag nagsesend, 1 kapag hindi


int REPORTINTERVAL = 30;
char MASTERNAME[5] = "SINB";
char PIEZONAME[7] = "SINBPZ";
char SERVERNUM[12] = "09176321023";
char MOBILENUM[12] = "09176321023"; 
int RETRYval = 1; 

//piezo global variables
//ALWAYS CHANGE every node
char PIEZOID[3] = "1E"; // set piezo ID larger than any other node, HEX

//File myFile;
char sleep = 0;


/************************************************************************************
 * MMC Function Declarations
/************************************************************************************/

void storeData(String, int);
void logData(String, String);
//int sentOK();
int sendDataFromFile(int);
int checkOutboxFiles();
int sdChk=0;
/************************************************************************************/


void setup(){
  unsigned long timestart = 0;
  unsigned long timenow = 0;
  boolean exit = false;
  char a = 0;
  char b = 0;
  char single[1] = {NULL};
  // initialize serial commsk

  sleep = 0;
  Serial.begin(57600);     // arduino debug
  Serial1.begin(57600);    // master column
  Serial2.begin(2400);
  pinMode(53, OUTPUT);
  pinMode(RELAYPIN, OUTPUT);
  pinMode(12, INPUT);
  pinMode(MMCPIN, OUTPUT); //MMC
  pinMode(MMCEN, OUTPUT);
  pinMode(MMCON,OUTPUT);
  pinMode(batLineRead, INPUT);
  pinMode(voltSwitch, OUTPUT);
  digitalWrite(MMCON,LOW);

  WDT_off();
  delay(1000);

  /***********************************************************/
  /*	EEPROM variables
  /***********************************************************/

  //Access EEPROM. Read, write and clear EEPROM data.
  Serial.println("\n\[a] Customize EEPROM\n[b] Continue to program\n");
  timestart = millis();
  timenow = millis();
  while( timenow - timestart < 3000 ){
    timenow = millis();
    if(Serial.available()){
      int eeTest = Serial.read();
      if(eeTest == 'a') eepromCHECK();
      else if(eeTest == 'b') break;
    }
  }


  if ( EEPROM.read(0) != 255){
    if((EEPROM.read(5)!= 255) && (EEPROM.read(5) < 61))  REPORTINTERVAL = EEPROM.read(5);  //REPORTINTERVAL data stored at address 5
  }
  if ( EEPROM.read(1) != 255){
    if(eepromCheckNull(10,4)==1) 
      for(int i=0;i<4;i++){
        MASTERNAME[i] = EEPROM.read(10+i);  //MASTERNAME data stored at address 10-13
      }
  }
  if ( EEPROM.read(2) != 255){
    if(eepromCheckNull(20,11)==1)
      for(int i=0;i<11;i++){
        SERVERNUM[i] = EEPROM.read(20+i);  //SERVERNUM data stored at address 20-30
      }
  }
  if ( EEPROM.read(3) != 255){
    if(eepromCheckNull(40,11)==1)
      for(int i=0;i<11;i++){
        MOBILENUM[i] = EEPROM.read(40+i);  //MOBILENUM data stored at address 40-50
      }
  }
  if ( EEPROM.read(4) != 255){
    if((EEPROM.read(6) < 21) && (EEPROM.read(6) > 0))  RETRYval = EEPROM.read(6);  //REPORTINTERVAL data stored at address 5
  }


  /***********************************************************/

  Serial.print("\nSENSLOPE ");
  Serial.print(MASTERNAME);
  Serial.println(" MASTER BOX");
  Serial.print("Build no:  ");
  Serial.println(BUILDNUMBER);
  Serial.print("Column data retry value: ");
  Serial.println(RETRYval);


  pinMode(13,OUTPUT);
  digitalWrite(13,HIGH);

  digitalWrite(voltSwitch,LOW);
  
  //*********************************// 
  // For MMC toggle to OFF           //
  //*********************************//
  digitalWrite(MMCON,LOW);
  digitalWrite(MMCEN,LOW);

  pinMode(50, OUTPUT);
  digitalWrite(50,LOW);
  pinMode(51, OUTPUT);
  digitalWrite(51,LOW);
  pinMode(52, OUTPUT);
  digitalWrite(52,LOW);
  pinMode(53, OUTPUT);
  digitalWrite(53,LOW);
  //*********************************//

  /* Enter GSM control state */

  timestart = millis();
  timenow = millis();
  Serial.println("Press anything to Enter GSM Control mode");
  while( timenow - timestart < 3000 ){
    timenow = millis();
    ///*
    if (Serial.available()){
      PowerGSM(ON);
      delay(2000);
      Serial2.flush();
      Serial.flush();
      while(1){
        if(Serial.available()){
          a = Serial.read();
          if ( a == '^' ){
            exit = true;
            break;
          }
          else  if( a == '@'){
            Serial2.print('\r'); 
            Serial2.print('\n');
          }
          else  if ( a == '#'){
            Serial2.print((char)0x1A);
            Serial.print((char)0x1A);
          }
          else Serial2.print(a);
        }
        if(Serial2.available()){
          Serial.print((char)Serial2.read());
        }
      }
    }

    if (exit) break;
  }
  if (timenow - timestart > 3000 ) Serial.println("GSM Control not entered.");
  else Serial.println("Exiting GSM Control");
  //
}

short sampFlg = 1;
short resetFlg = 0;
short resFlg = 0;
volatile long globalTime = 0;
char *columnData = NULL;

char *msgToSend = NULL;
char *FinalMsg = NULL;
char Timestamps[17];
char logfile[8]; //dinagdag lang
char filenameDate[12];
char *buffer = NULL;
char *sndFlg= NULL;

unsigned int k = 0;

char piezo_data[20];
int piezopresent = 0;

void loop(){
  char *temp2 = NULL;
  //char *messages = NULL;
  unsigned char msgno = 0;
  char *ptr = NULL;
  char *stat = NULL;
  char *number = NULL;
  char *temp = NULL;
  char *msg = NULL;
  char *sender = NULL;	
  char *ack = NULL;
  char *csqC= NULL;


  boolean invCmd = 1;

  int chckOF=0;
  int sndFrmFile = 0;
  int simC = 0;

  /***********************************************************/
  /*	Memory allocations
  /***********************************************************/

  temp2 = (char *) calloc(15, sizeof(char *));
  temp = (char *) calloc(25, sizeof(char *));
  //messages = (char *) calloc(150, sizeof(char *));
  number = (char *) calloc(10, sizeof(char *));
  msg = (char *) calloc(160, sizeof(char *));
  ptr = (char *) calloc(100, sizeof(char *));
  sender = (char *) calloc(10, sizeof(char *));  //dagdag ko
  ack = (char *) calloc(50, sizeof(char *));  //dagdag ko

  columnData = (char *) calloc(730, sizeof(char *));

  msgToSend = (char *) calloc(200, sizeof(char *));   
  buffer = (char *) calloc(100, sizeof(char *));
  csqC= (char *) calloc(3, sizeof(char *));	
  sndFlg= (char *) calloc(1, sizeof(char *));
  


  /***********************************************************/
  /*	Sampling data from column
  /***********************************************************/
  //delay(15000);
  float columnLen = 0.0;
  float loopnum = 0.0;
  short retry = 0;
  short endpiezo = RETRYval-1;
  
  while (retry < RETRYval){//columLen<120
    char tempData[730];
    clearString(tempData);
    //delay(2000);
    Serial.println("\nEntered column data polling loop");
    TURN_COLUMN_ON;
    delay(2000);
    Serial1.flush();
    GetColumnData(tempData);
    TURN_COLUMN_OFF;
   
    

    for(k=0; tempData[k] != 0x00; k++){
      Serial.print(tempData[k]);
      if ((k+1)%15 == 0) Serial.print("\n");
    }
    Serial.println();

    if(RETRYval > 1){
      concatColumnData(columnData,tempData);
      //add BB at the end of columnData
      if(strlen(columnData) % 15 == 0){
        Serial.println("adding BB...");
        columnData[strlen(columnData)] = 'B';
        columnData[strlen(columnData)] = 'B';
      }
      for(k=0; columnData[k] != 0x00; k++){
        Serial.print(columnData[k]);
        if ((k+1)%15 == 0) Serial.print("\n");
      }
    }
    else{
      strcpy(columnData,tempData);
    }
    clearString(tempData); 
  
      if(WITHPIEZO == 1 && retry == endpiezo){
        getPiezoData(columnData,piezo_data);
        Serial.print("piezo data obtained for retry: ");
        Serial.println(retry);
        Serial.println(piezo_data);
        Serial.print("column data obtained for retry: ");
        Serial.println(retry);
        Serial.println(columnData);
        
          if((piezo_data[0] == PIEZOID[0]) && (piezo_data[1] == PIEZOID[1]))
            piezopresent = 1;
      }

    columnLen = strlen(columnData);
    loopnum = ceil((columnLen/135.0));
    delay(2000);
    retry = retry + 1;
  }
  //delay(15000);

  /***********************************************************/
  /*	Initializing GSM module and global time variables
  /***********************************************************/
  //SPI.setClockDivider(SPI_CLOCK_DIV128);
  Serial.println("MMC begin");
  /*  MMC initialization*/
  digitalWrite(MMCEN,HIGH);
  delay(1000);
  digitalWrite(MMCON,HIGH);
  Serial.println("Turning ON MMC...");
  delay(1000);
  
  if(!SD.begin(MMCPIN)){
    Serial.println(" SD card not found! ");
    sdChk= 0;
  }
  else{
    Serial.println(" Initializing MMC... ");
    sdChk= 1;
  }
  Serial.println("SD check done...");


  InitGSM();
  delay(5000);
  globalTime = GetTimestampTag(Timestamps, logfile);
  Serial.print("\nGlobalTime: ");
  Serial.println(globalTime, DEC);
  time_conf();

  /***********************************************************/
  /*	Sending column data to GSM
  /***********************************************************/
  int numberOfMessages = loopnum;
  if (loopnum <= 0){
    // in cases where no there is an error parsing the data
    sprintf(msgToSend, "%s::", MASTERNAME);
    strncat(msgToSend, "ERROR: no data parsed :: ", 21);
    strncat(msgToSend, Timestamps, strlen(Timestamps));

    int help = okToSend(&simC,csqC,   buffer,sndFlg);
    if (help && !SendMsg(SERVERNUM, msgToSend, buffer)){
      Serial.println("The system is now sending via GSM");
      SendMsg(MOBILENUM, msgToSend, buffer);
      sndFrmFile= 1;
    }
    else{
      Serial.print(sdChk);
      if (sdChk==1){
        storeData(msgToSend,chckOF);
        sndFrmFile= 0;
      } 
    }//end of if sent or not

  }
  else{
    while (loopnum > 0){
      sprintf(msgToSend, "%s*", MASTERNAME); 
      strncat(msgToSend, columnData, 135);
      strncat(msgToSend, "*", 1);
      strncat(msgToSend, Timestamps, strlen(Timestamps));
      columnData = columnData + 135;
      loopnum=loopnum-1;

      String dateToday = logfile;

      String msgToLog= msgToSend;
      if (sdChk==1){
        logData(dateToday + ".txt", msgToLog + "\r\n");
        chckOF= checkOutboxFiles();
      }

      delay(300);

      int help = okToSend(&simC,csqC,   buffer,sndFlg);

      if (help && !SendMsg(SERVERNUM, msgToSend, buffer)){
        Serial.println("The system is now trying to send data via GSM");
        SendMsg(MOBILENUM, msgToSend, buffer);
        sndFrmFile= 1;
      }
      else{
        Serial.print(sdChk);
        if (sdChk==1){
          storeData(msgToSend,chckOF);
          sndFrmFile= 0;
        } 
      }

      delay(700);
    } 

  }

  //send piezo data
  if(piezopresent == 1){
     Serial.println("Sending Piezo Data via GSM");
     Serial.println(PIEZONAME);
    sprintf(msgToSend, "%s*", PIEZONAME); 
    strncat(msgToSend, piezo_data, strlen(piezo_data));
    strncat(msgToSend, "*", 1);
    strncat(msgToSend, Timestamps, strlen(Timestamps));
    SendMsg(SERVERNUM, msgToSend, buffer);
    piezo_data[0] = '\0';
  }

  //free(piezodata);
  

  free(columnData);	
  fix28135_malloc_bug();

  if (sdChk==1){
    Serial.println("Sending DatafromFile");
    if (sndFrmFile == 1){
      int k=0;
      Serial.print("chckOF: ");
      Serial.println(chckOF);
      for (k=chckOF + 1; k > -1 ; k--)
        if (sendDataFromFile(k) == 1){
          break;
        }
    }
  }


  /***********************************************************/
  /*	Monitoring voltage status
  /***********************************************************/

  float voltage = 0;
  int voltStatus = 0;
  int batLine = 0;

  voltage = readVoltage();
  batLine = readVoltStatus();
  dtostrf(voltage,2,2,temp2);

  sprintf(msgToSend, "%s-%s,%d,%d/%d,#%d,%d,%s,%d*", MASTERNAME,temp2,batLine,retry,RETRYval,numberOfMessages,simC,csqC,sdChk);
  //sprintf(msgToSend, "%s-%s,%d,%d,%s,%s,%d*", MASTERNAME,temp2,batLine,numberOfMessages,simC,csqC,sdChk);
  //sprintf(msgToSend, "%s-%s,%d*", MASTERNAME,temp2,batLine);
  strncat(msgToSend, Timestamps, strlen(Timestamps));  
  Serial.println("\nSending voltage status:");
  Serial.println(msgToSend);

//  if (sdChk==1){
//    globalTime = GetTimestampTag(Timestamps, logfile);
//    String dateToday = logfile;
//    String msgToLog= msgToSend;
//    logData(dateToday + ".txt", msgToLog + "\r\n");
//  }
//
//  if ((SendMsg(SERVERNUM, msgToSend, buffer)) == 1){    
//    if (sdChk==1){
//      chckOF= checkOutboxFiles();
//      storeData(msgToSend,chckOF);
//    }
//  }

  delay(500);

  //free(msgToSend);	
  //fix28135_malloc_bug();
  free(FinalMsg);		
  fix28135_malloc_bug();
  free(buffer);		
  fix28135_malloc_bug();

  // MMC disable
  digitalWrite(MMCON,LOW);
  digitalWrite(MMCEN,LOW);
  
  /***********************************************************/
  /*	Load maintenance operations
  /***********************************************************/
  delay(5000);
  Serial.println("\n\nChecking Inbox for command messages.. ");
  for (msgno = 1; msgno < 11; msgno++){
    sprintf(temp2, "AT+CMGR=%d\r\n",msgno);
    SendATcmd(temp2, msgToSend, sndFlg);
    //Serial.print("messages: ");
    //Serial.println(messages);

    if((strstr(msgToSend,"\"+6"))){
      Serial.println("Msg rcvd from a CELL #");
      ptr = strtok(msgToSend,"6");//from 6 to double quote
      ptr = strtok(NULL,"\"");
    }
    //else strcpy(ptr,messages);  //copy messages to ptr otherwise
    else {
      ptr = strtok(msgToSend,",");//from comma to double quote
      ptr = strtok(NULL,"\"");
    }
    //ptr = strtok(messages, "6");  //Eto ung original. Not meant to read messages from the network
    while(ptr != NULL){
      if (strlen(ptr)>3){
        //ptr = strtok(NULL,"\r");
        strncpy(sender,ptr,strlen(ptr));
        sender[strlen(ptr)] = '\0';

        Serial.print("Sender: ");
        Serial.println(sender); 
        if (strlen(ptr) == 11)  sender[0] = '0';
        Serial.print("::");
        ptr = strtok(NULL,"\r");
        stat = NULL;

        if (strstr(sender, "SMARTLoad")){//change to "Smart"
          stat = strstr(sender, "SMARTLoad");
          ;
        }
        else if (strstr(sender, "SMART")){
          stat = strstr(sender, "SMART");
        }
        else if (strstr(sender, "BUDDY")){
          stat = strstr(sender, "BUDDY");
        }
        //additional numbers for globe
        else if (strstr(sender, "GLOBE")){
          stat = strstr(sender, "GLOBE");
        }
        else if (strstr(sender, "222")){
          stat = strstr(sender, "222");
        }
        else if (strstr(sender, "8888")){
          stat = strstr(sender, "8888");
        }
        else if (strstr(sender, "3733")){
          stat = strstr(sender, "3733");
        }
        //additional number for sun
        else if (strstr(sender, "7210")){
          stat = strstr(sender, "7210");
        }

        ptr = strtok(NULL, "\r"); //extracts the message

        // if number is from SMART, send message immediately to REPNUM
        if (stat != NULL){
          Serial.print("Message rcvd from: ");
          Serial.println(sender);
          Serial.println("Sending to MOBILE and SERVER #...");
          SendMsg(SERVERNUM, ptr, temp);
          delay(1000);
          SendMsg(MOBILENUM, ptr, temp);
        }
        // else check to see if it is a valid command message
        else if (strstr(ptr, CMDKEY)){
          // Serial.println("Command detected");
          ptr = strtok(ptr,",");  //  *#CMD#*
          ptr = strtok(NULL,",");  //  Cmd type
          strncpy(msg,ptr,strlen(ptr));  // copy the Cmd type to msg
          ptr = strtok(NULL,",");
          strcpy(number,ptr);  //  copy the data to number

            // command message: *#CMD#*,<cmd type>,<p1>,<p2>,...,<pn>
          if (strstr(msg, "SEND")){
            ptr = strtok(NULL, ","); // message to send
            Serial.println(ptr);
            SendMsg(sender,ptr,temp);
            delay(1000);
            SendMsg(number, ptr, temp);
            delay(1000);
            SendMsg(SERVERNUM, ptr, temp);
            delay(1000);
            SendMsg(MOBILENUM, ptr, temp);
          }

          //GSM commands to change EEPROM variables

          /***********************************************************/
          /*    GSM EEPROM COMMANDS
          /***********************************************************/
          else  if (strstr(msg, "CINT")){
            if(strstr(number,"RESET")){
              EEPROM.write(0,255);  //Check for RESET string to switch to defualt value
              sprintf(ack,"CINT RESET");
            }
            else if((atoi(number)>0) && (atoi(number)<=60)){
              EEPROM.write(0,1);
              EEPROM.write(5,atoi(number));
              REPORTINTERVAL = atoi(number);
              sprintf(ack,"Ack,CINT,%s", number);
            }
            else{
              sprintf(ack,"Err,CINT,%s",number);
            }
            SendMsg(sender,ack,temp);
          }//end of cint
          else if (strstr(msg, "CNME")){
            if(strstr(number,"RESET")){
              EEPROM.write(1,255);  //Check for RESET string to switch to defualt value
              sprintf(ack,"CNME RESET");
            }
            else if(strlen(number)==4){
              EEPROM.write(1,1);
              eepromCmdWrite(10,4,number);
              sprintf(ack,"Ack CNME: %s", number);
            }
            else{
              sprintf(ack,"Err,CNME,%s",number);
            }
            SendMsg(sender,ack,temp);
          }//end of cnme
          else if (strstr(msg, "CSER")){
            if(strstr(number,"RESET")){
              EEPROM.write(2,255); //Check for RESET string to switch to defualt value
              sprintf(ack,"CSER RESET");
            }
            else if(strlen(number)==11){
              EEPROM.write(2,1);
              eepromCmdWrite(20,11,number);
              sprintf(ack,"Ack CSER: %s", number);
            }
            else{
              sprintf(ack,"Err,CSER,%s",number);
            }
            SendMsg(sender,ack,temp);
          }//end of cser
          else if (strstr(msg, "CMOB")){
            if(strstr(number,"RESET")){
              EEPROM.write(3,255);  //Check for RESET string to switch to defualt value
              sprintf(ack,"CMOB RESET");
            }
            else if(strlen(number)==11){
              EEPROM.write(3,1);
              eepromCmdWrite(40,11,number);
              sprintf(ack,"Ack CMOB: %s", number);
            }
            else{
              sprintf(ack,"Err,CMOB,%s",number);
            }
            SendMsg(sender,ack,temp);
          }//end of cmob
          else  if (strstr(msg, "CRET")){
            if(strstr(number,"RESET")){
              EEPROM.write(4,255);  //Check for RESET string to switch to defualt value
              sprintf(ack,"CRET RESET");
            }
            else if((atoi(number)>0) && (atoi(number)<=60)){
              EEPROM.write(4,1);
              EEPROM.write(6,atoi(number));
              REPORTINTERVAL = atoi(number);
              sprintf(ack,"Ack,CRET,%s", number);
            }
            else{
              sprintf(ack,"Err,CRET,%s",number);
            }
            SendMsg(sender,ack,temp);
          }//end of cret
          /*
           format: yy/MM/dd,hh:mm:ss+zz
           or yy/MM/dd,hh:mm:ss-zz
           ,where zz is the time zone
           */
          else if (strstr(msg, "CCLK")){
            ptr = strtok(NULL, ",");
            sprintf(ack,"AT+CCLK=\"%s,%s\"\r\n",number,ptr);
            if(strlen(ack)==32){
              Serial.println(ack);
              SendATcmd(ack,msgToSend,sndFlg);
              clearString(ack);
              sprintf(ack,"AT+CCLK?\r\n");//new
              SendATcmd(ack,msgToSend,sndFlg);//new
              //strcat(messages," ~ Ack");
              SendMsg(sender,msgToSend,temp);
            }
          }
          /***********************************************************/
          /*    END OF GSM EEPROM COMMANDS
          /***********************************************************/
        }//End of CMDKEY stuff

      }
      ptr = strtok(NULL, "\r");
    }
    if (DELMSG){
      sprintf(temp2, "AT+CMGD=%d\r\n",msgno);
      SendATcmd(temp2, temp, sndFlg);
    }

  }//end of number of messages to check	
  free(number);	
  fix28135_malloc_bug();
  free(temp2);	
  fix28135_malloc_bug();
  free(ptr);	
  fix28135_malloc_bug();
  free(temp);	
  fix28135_malloc_bug();
  free(sender);   
  fix28135_malloc_bug();
  free(ack);      
  fix28135_malloc_bug();
  free(sndFlg);	
  fix28135_malloc_bug();

  // in case of long message sending times
  // get globaltime again
  globalTime = GetTimestampTag(Timestamps, logfile);
  Serial.print("\nGlobalTime: ");
  Serial.println(globalTime, DEC);
  time_conf();


  /***********************************************************/
  /*	Powering down whole system
  /***********************************************************/
  PowerGSM(OFF);
  Serial.print("Entering sleep mode...");

  sleepNow();	

  Serial.println(" done");
  delay(3000);
}

void time_conf(){
  TIMSK5 &= ~(1<<TOIE5);  
  TCCR5A &= ~((1<<WGM51) | (1<<WGM50));  
  TCCR5B &= ~(1<<WGM22);  
  ASSR &= ~(1<<AS2);   
  TIMSK5 &= ~(1<<OCIE5A);    
  TCCR5B |= (1<<CS52);
  TCCR5B &= ~(1<<CS51);
  TCCR5B |= (1<<CS50);     
  TCNT5 = 49911;
  TIMSK5 |= (1<<TOIE5);  
} 

/*
  globalTime -> variable to represent time in seconds from nearest hour
 i.e.
 
 GSM time: 11:10:26 >> globalTime = 10*60 + 26
 GSM time: 09:25:15 >> globalTime = 25*60 + 15
 
 Sampling will start when globalTime % REPORTINTERVAL = 0
 In other words, when globalTime is a factor of REPORTINTERVAL
 
 */
ISR(TIMER5_OVF_vect)
{ 
  //Serial.print(TCNT5, DEC);
  TCNT5 = 49911;

  globalTime++;

  //if (globalTime % 0 == 0){
  if (globalTime % (REPORTINTERVAL*60) == 0){
    sleep_disable();
    power_all_enable();
    asm volatile ("jmp 0x0000");
  }
}

void sleepNow(){
  set_sleep_mode(SLEEP_MODE_IDLE);   // sleep mode is set here

  sleep_enable();          // enables the sleep bit in the mcucr register
  // so sleep is possible. just a safety pin at

  power_adc_disable();
  power_spi_disable();
  power_timer0_disable();
  power_timer1_disable();
  power_timer2_disable();
  power_timer3_disable();
  power_timer4_disable();
  power_twi_disable();

  sleep_mode();        
}

void WDT_off(void){
  asm("cli");
  asm("wdr");

  MCUSR &= ~(1<<WDRF);
  WDTCSR |= (1<<WDCE) | (1<<WDE);
  WDTCSR = 0x00;
  asm("sei");
}

void WDT_Prescaler_Change(void){
  asm("cli");
  asm("wdr");

  WDTCSR |= (1<<WDCE) | (1<<WDE);
  WDTCSR = (1<<WDE) | (1 <<WDP3) | (1<<WDP0);
  asm("sei");
}

void clearString(char *strArray) {
  int j;
  for (j = 0; j < strlen(strArray); j++)
    strArray[j] = 0x00;
}

